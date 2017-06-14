#include <OpenDirectory/OpenDirectory.h>

ODNodeRef CreateNode(void);

ODRecordRef CopyGroupRecordWithGID(ODNodeRef, gid_t);

ODRecordRef CopyUserRecordWithUID(ODNodeRef, uid_t);
ODRecordRef CopyUserRecordWithUsername(ODNodeRef, char *);

CFArrayRef CopyGroupRecordsForUser(ODNodeRef, ODRecordRef, CFIndex);

CFStringRef CopyAttrFromRecord(ODRecordRef record, CFStringRef attribute);
int GetIntAttrFromRecord(ODRecordRef record, CFStringRef attribute, int *output);
uid_t GetUIDFromRecord(ODRecordRef);
gid_t GetGIDFromRecord(ODRecordRef);

int cfprintf(FILE *file, const char *format, ...);
int cprintf(const char *format, ...);
