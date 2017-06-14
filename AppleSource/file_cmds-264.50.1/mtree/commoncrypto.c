#include <dispatch/dispatch.h>
#include <os/assumes.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/xattr.h>
#include <stdbool.h>
#include <err.h>
#include <errno.h>
#include <stdio.h>
#include <sys/attr.h>
#include <unistd.h>

#include "commoncrypto.h"

const int kSHA256NullTerminatedBuffLen = 65;
static const char hex[] = "0123456789abcdef";

/* Functions for SHA256_File_XATTRs */
#define SHA256_Data(d, s, b)    Digest_Data(kCCDigestSHA256, d, s, b)
char *Digest_Data(CCDigestAlg algorithm, void *data, size_t size, char *buf);
void Quicksort(char **array, int num);

/* Generic version of libmd's *_File() functions. */
char *
Digest_File(CCDigestAlg algorithm, const char *filename, char *buf)
{
	int fd;
	__block CCDigestCtx ctx;
	dispatch_queue_t queue;
	dispatch_semaphore_t sema;
	dispatch_io_t io;
	__block int s_error = 0;
	uint8_t digest[32]; // SHA256 is the biggest
	size_t i, length;

	/* dispatch_io_create_with_path requires an absolute path */
	fd = open(filename, O_RDONLY);
	if (fd < 0) {
		return NULL;
	}

	(void)fcntl(fd, F_NOCACHE, 1);

	(void)os_assumes_zero(CCDigestInit(algorithm, &ctx));

	queue = dispatch_queue_create("com.apple.mtree.io", NULL);
	os_assert(queue);
	sema = dispatch_semaphore_create(0);
	os_assert(sema);

	io = dispatch_io_create(DISPATCH_IO_STREAM, fd, queue, ^(int error) {
		if (error != 0) {
			s_error = error; 
		}
		(void)close(fd);
		(void)dispatch_semaphore_signal(sema);
	});
	os_assert(io);
	dispatch_io_read(io, 0, SIZE_MAX, queue, ^(__unused bool done, dispatch_data_t data, int error) {
		if (data != NULL) {
			(void)dispatch_data_apply(data, ^(__unused dispatch_data_t region, __unused size_t offset, const void *buffer, size_t size) {
				(void)os_assumes_zero(CCDigestUpdate(&ctx, buffer, size));
				return (bool)true;
			});
		}

		if (error != 0) {
			s_error = error;
		}
	});
	dispatch_release(io); // it will close on its own

	(void)dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

	dispatch_release(queue);
	dispatch_release(sema);

	if (s_error != 0) {
		errno = s_error;
		return NULL;
	}

	/* Finalize and convert to hex. */
	(void)os_assumes_zero(CCDigestFinal(&ctx, digest));
	length = CCDigestOutputSize(&ctx);
	os_assert(length <= sizeof(digest));
	for (i = 0; i < length; i++) {
		buf[i+i] = hex[digest[i] >> 4];
		buf[i+i+1] = hex[digest[i] & 0x0f];
	}
	buf[i+i] = '\0';
	
	return buf;
}

char *SHA256_Path_XATTRs(char *path, char *buf)
{
	char *xattrsSummary = NULL;
	int options = XATTR_SHOWCOMPRESSION | XATTR_NOFOLLOW;
	ssize_t nameBufSize = listxattr(path, NULL, 0, options);
	if (nameBufSize > 0) {
		char *nameBuf = malloc(nameBufSize);
		
		listxattr(path, nameBuf, nameBufSize, options);
		
		size_t xattrsLen = 1;
		size_t xattrIndex = 0;
		char **xattrs = malloc(xattrsLen * sizeof(char *));
		char *nextName = nameBuf;
		while (nextName < nameBuf + nameBufSize)
		{
			char *name = nextName;
			if (xattrIndex == xattrsLen) {
				xattrsLen *= 2;
				xattrs = realloc(xattrs, xattrsLen * sizeof(char *));
			}
			xattrs[xattrIndex++] = name;
			nextName += strlen(name) + 1;
		}
		
		// sort the xattr array as they're not guaranteed to come in the same order
		qsort_b(xattrs, xattrIndex, sizeof(char *), ^(const void *l, const void *r) {
			char *left = *(char **)l;
			char *right = *(char **)r;
			return strcmp(left, right);
		});
		
		// gather the data for the xattrs
		bool didAddXATTR = false;
		int xattrBufLen = kSHA256NullTerminatedBuffLen;
		void *xattrBuf = malloc(xattrBufLen); // resized if necessary
		char *digest;
		ssize_t result = 0;
		char *oldSummary = NULL;
		for (int i = 0; i < xattrIndex; i++) {
			char *name = xattrs[i];
			ssize_t xlen = getxattr(path, name, NULL, 0, 0, options);
			if (xlen > xattrBufLen) {
				xattrBufLen = xlen;
				xattrBuf = realloc(xattrBuf, xattrBufLen);
			}
			bzero(xattrBuf, xattrBufLen);
			result = getxattr(path, name, xattrBuf, xattrBufLen, 0, options);
			if (result < 0)
				err(1, "SHA256_Path_XATTRs: getxattr");
			
			digest = SHA256_Data(xattrBuf, xattrBufLen, buf);
			if (!digest)
				err(1, "%s", xattrsSummary);
			if (!didAddXATTR)
			{
				didAddXATTR = true;
				asprintf(&xattrsSummary, "%s:%s", name, digest);
			} else {
				oldSummary = xattrsSummary;
				asprintf(&xattrsSummary, "%s, %s:%s", oldSummary, name, digest);
				free(oldSummary);
			}
		}
		
		free(xattrBuf);
		free(nameBuf);
		free(xattrs);
		
		digest = SHA256_Data(xattrsSummary, strlen(xattrsSummary) * sizeof(char), buf);
		if (!digest)
			err(1, "%s", xattrsSummary);
		
		free(xattrsSummary);
		return digest;
	}
	return kNone;
}

char *SHA256_Path_ACL(char *path, char *buf)
{
	int result		= 0;
	char *data		= NULL;
	char *digest		= NULL;
	
	struct attrlist list = {
		.bitmapcount	= ATTR_BIT_MAP_COUNT,
		.commonattr	= ATTR_CMN_RETURNED_ATTRS | ATTR_CMN_EXTENDED_SECURITY,
	};
	
	struct ACLBuf {
		uint32_t		len;
		attribute_set_t		returned_attrs;
		attrreference_t		acl;
		char			buf[8192]; // current acls are up to 3116 bytes, but they may increase in the future
	} __attribute__((aligned(4), packed));
	
	struct ACLBuf aclBuf;
	
	result = getattrlist(path, &list, &aclBuf, sizeof(aclBuf), FSOPT_NOFOLLOW);
	
	if (result)
		err(1, "SHA256_Path_ACL: getattrlist");
	
	// if the path does not have an acl, return none
	if ( ( ! ( aclBuf.returned_attrs.commonattr & ATTR_CMN_EXTENDED_SECURITY ) )
	    || ( aclBuf.acl.attr_length == 0 ) ) {
		return kNone;
	}
	
	data = ((char*)&aclBuf.acl) + aclBuf.acl.attr_dataoffset;
	
	digest = SHA256_Data(data, aclBuf.acl.attr_length, buf);
	if (!digest)
		err(1, "SHA256_Path_ACL: SHA256_Data");
	
	return digest;
}

/* Functions for Digest_Path_* */
char *
Digest_Data(CCDigestAlg algorithm, void *data, size_t size, char *buf) {
	
	uint8_t digest[32]; // SHA256 is the biggest
	CCDigestCtx ctx;
	size_t i, length;
	
	(void)os_assumes_zero(CCDigestInit(algorithm, &ctx));
	(void)os_assumes_zero(CCDigestUpdate(&ctx, data, size));
	
	/* Finalize and convert to hex. */
	(void)os_assumes_zero(CCDigestFinal(&ctx, digest));
	length = CCDigestOutputSize(&ctx);
	os_assert(length <= sizeof(digest));
	for (i = 0; i < length; i++) {
		buf[i+i] = hex[digest[i] >> 4];
		buf[i+i+1] = hex[digest[i] & 0x0f];
	}
	buf[i+i] = '\0';
	
	return buf;
}

