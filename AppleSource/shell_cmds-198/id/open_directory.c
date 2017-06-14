#include <membership.h>

#include "open_directory.h"

ODNodeRef
CreateNode(void)
{
	CFErrorRef error = NULL;
	ODNodeRef node = NULL;

	node = ODNodeCreateWithNodeType(NULL, kODSessionDefault, kODTypeAuthenticationSearchNode, &error);

	if (node == NULL) {
		CFShow(error);
		exit(1);
	}

	return node;
}

static ODRecordRef
CopyRecordWithUUID(ODNodeRef node, CFStringRef type, uuid_t uuid)
{
	CFErrorRef error = NULL;
	char uuidstr[37];
	CFStringRef uuidref;
	ODQueryRef query = NULL;
	CFTypeRef vals[] = { CFSTR(kDSAttributesStandardAll) };
	CFArrayRef attributes = CFArrayCreate(NULL, vals, 1, &kCFTypeArrayCallBacks);
	CFArrayRef results = NULL;
	ODRecordRef record = NULL;

	uuid_unparse(uuid, uuidstr);
	uuidref = CFStringCreateWithCString(NULL, uuidstr, kCFStringEncodingUTF8);

	if (uuidref) {
		query = ODQueryCreateWithNode(NULL, node, type, CFSTR(kDS1AttrGeneratedUID), kODMatchEqualTo, uuidref, attributes, 100, &error);

		if (query) {
			results = ODQueryCopyResults(query, false, &error);

			if (results) {
				if (CFArrayGetCount(results) == 1) {
					record = (ODRecordRef)CFArrayGetValueAtIndex(results, 0);
					CFRetain(record);
				}

				CFRelease(results);
			}

			CFRelease(query);
		}

		CFRelease(uuidref);
	}

	return record;
}

ODRecordRef
CopyGroupRecordWithGID(ODNodeRef node, gid_t gid)
{
	uuid_t uuid;

	mbr_gid_to_uuid(gid, uuid);

	return CopyRecordWithUUID(node, CFSTR(kDSStdRecordTypeGroups), uuid);
}

ODRecordRef
CopyUserRecordWithUID(ODNodeRef node, uid_t uid)
{
	uuid_t uuid;

	mbr_uid_to_uuid(uid, uuid);

	return CopyRecordWithUUID(node, CFSTR(kDSStdRecordTypeUsers), uuid);
}

ODRecordRef
CopyUserRecordWithUsername(ODNodeRef node, char *name)
{
	CFStringRef nameref;
	CFTypeRef vals[] = { CFSTR(kDSAttributesStandardAll) };
	CFArrayRef attributes = CFArrayCreate(NULL, vals, 1, &kCFTypeArrayCallBacks);
	CFErrorRef error;

	nameref = CFStringCreateWithCString(NULL, name, kCFStringEncodingUTF8);

	if (nameref == NULL)
		return NULL;

	return ODNodeCopyRecord(node, CFSTR(kDSStdRecordTypeUsers), nameref, attributes, &error);
}

CFStringRef
CopyAttrFromRecord(ODRecordRef record, CFStringRef attribute)
{
	CFErrorRef error = NULL;
	CFArrayRef values = ODRecordCopyValues(record, attribute, &error);
	CFStringRef result = NULL;

	if (values) {
		if (CFArrayGetCount(values) == 1) {
			result = CFArrayGetValueAtIndex(values, 0);
			CFRetain(result);
		}
		CFRelease(values);
	}

	return result;
}

int
GetIntAttrFromRecord(ODRecordRef record, CFStringRef attribute, int *output)
{
	int status = 1;
	CFStringRef str = CopyAttrFromRecord(record, attribute);

	if (str) {
		*output = CFStringGetIntValue(str);
		status = 0;
		CFRelease(str);
	}

	return status;
}

uid_t
GetUIDFromRecord(ODRecordRef record)
{
	int uid = -1;

	GetIntAttrFromRecord(record, CFSTR(kDS1AttrUniqueID), &uid);

	return uid;
}

gid_t
GetGIDFromRecord(ODRecordRef record)
{
	int gid = -1;

	GetIntAttrFromRecord(record, CFSTR(kDS1AttrPrimaryGroupID), &gid);

	return gid;
}

CFArrayRef
CopyGroupRecordsForUser(ODNodeRef node, ODRecordRef user, CFIndex limit)
{
	CFMutableArrayRef groups;
	gid_t primary_gid;
	ODRecordRef primary_group;
	CFErrorRef error = NULL;
	ODQueryRef query;
	CFArrayRef results;
	int i;
	ODRecordRef gr;

	query = ODQueryCreateWithNode(NULL, node, CFSTR(kDSStdRecordTypeGroups),
		CFSTR(kDSNAttrMember), kODMatchContains, ODRecordGetRecordName(user), NULL, limit, &error);
	results = ODQueryCopyResults(query, false, &error);
	CFRelease(query);

	groups = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);

	primary_gid = GetGIDFromRecord(user);
	primary_group = CopyGroupRecordWithGID(node, primary_gid);
	CFArrayAppendValue(groups, primary_group);
	CFRelease(primary_group);

	for (i = 0; i < CFArrayGetCount(results); i++) {
		gr = (ODRecordRef)CFArrayGetValueAtIndex(results, i);
		if (GetGIDFromRecord(gr) != primary_gid) {
			CFArrayAppendValue(groups, gr);
		}
	}

	CFRelease(results);

	return groups;
}

static int
cvfprintf(FILE *file, const char *format, va_list args)
{
		char* cstr;
		int result = 0;
        CFStringRef formatStr = CFStringCreateWithCStringNoCopy(NULL, format, kCFStringEncodingUTF8, kCFAllocatorNull);
		if (formatStr) {
			CFStringRef str = CFStringCreateWithFormatAndArguments(NULL, NULL, formatStr, args);
			if (str) {
				size_t size = CFStringGetMaximumSizeForEncoding(CFStringGetLength(str), kCFStringEncodingUTF8) + 1;
				cstr = malloc(size);
				if (cstr && CFStringGetCString(str, cstr, size, kCFStringEncodingUTF8)) {
					result = fprintf(file, "%s", cstr);
					free(cstr);
				}
				CFRelease(str);
			}
			CFRelease(formatStr);
		}
		return result;
}

int
cfprintf(FILE *file, const char *format, ...)
{
	int result;
	va_list args;

	va_start(args, format);
	result = cvfprintf(file, format, args);
	va_end(args);
	return result;
}

int
cprintf(const char *format, ...)
{
	int result;
	va_list args;

	va_start(args, format);
	result = cvfprintf(stdout, format, args);
	va_end(args);
	return result;
}
