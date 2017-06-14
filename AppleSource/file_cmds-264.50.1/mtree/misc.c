/*-
 * Copyright (c) 1991, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#if 0
#ifndef lint
static char sccsid[] = "@(#)misc.c	8.1 (Berkeley) 6/6/93";
#endif /*not lint */
#endif
#include <sys/cdefs.h>
__FBSDID("$FreeBSD: src/usr.sbin/mtree/misc.c,v 1.16 2005/03/29 11:44:17 tobez Exp $");

#include <sys/types.h>
#include <sys/stat.h>
#include <err.h>
#include <fts.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>
#include "mtree.h"
#include "extern.h"
#import <sys/attr.h>
#include <vis.h>

typedef struct _key {
	const char *name;			/* key name */
	u_int val;			/* value */

#define	NEEDVALUE	0x01
	u_int flags;
} KEY;

/* NB: the following table must be sorted lexically. */
static KEY keylist[] = {
	{"acldigest",		F_ACL,		NEEDVALUE},
	{"atime",		F_ATIME,	NEEDVALUE},
	{"btime",		F_BTIME,	NEEDVALUE},
	{"cksum",		F_CKSUM,	NEEDVALUE},
	{"ctime",		F_CTIME,	NEEDVALUE},
	{"flags",		F_FLAGS,	NEEDVALUE},
	{"gid",			F_GID,		NEEDVALUE},
	{"gname",		F_GNAME,	NEEDVALUE},
	{"ignore",		F_IGN,		0},
	{"inode",		F_INODE,	NEEDVALUE},
	{"link",		F_SLINK,	NEEDVALUE},
#ifdef ENABLE_MD5
	{"md5digest",		F_MD5,		NEEDVALUE},
#endif
	{"mode",		F_MODE,		NEEDVALUE},
	{"nlink",		F_NLINK,	NEEDVALUE},
	{"nochange",		F_NOCHANGE,	0},
	{"ptime",		F_PTIME,	NEEDVALUE},
#ifdef ENABLE_RMD160
	{"ripemd160digest",	F_RMD160,	NEEDVALUE},
#endif
#ifdef ENABLE_SHA1
	{"sha1digest",		F_SHA1,		NEEDVALUE},
#endif
#ifdef ENABLE_SHA256
	{"sha256digest",	F_SHA256,	NEEDVALUE},
#endif
	{"size",		F_SIZE,		NEEDVALUE},
	{"time",		F_TIME,		NEEDVALUE},
	{"type",		F_TYPE,		NEEDVALUE},
	{"uid",			F_UID,		NEEDVALUE},
	{"uname",		F_UNAME,	NEEDVALUE},
	{"xattrsdigest",	F_XATTRS,	NEEDVALUE},
};

int keycompare(const void *, const void *);

u_int
parsekey(char *name, int *needvaluep)
{
	KEY *k, tmp;

	tmp.name = name;
	k = (KEY *)bsearch(&tmp, keylist, sizeof(keylist) / sizeof(KEY),
	    sizeof(KEY), keycompare);
	if (k == NULL)
		errx(1, "line %d: unknown keyword %s", lineno, name);

	if (needvaluep)
		*needvaluep = k->flags & NEEDVALUE ? 1 : 0;
	return (k->val);
}

int
keycompare(const void *a, const void *b)
{
	return (strcmp(((const KEY *)a)->name, ((const KEY *)b)->name));
}

char *
flags_to_string(u_long fflags)
{
	char *string;

	string = fflagstostr(fflags);
	if (string != NULL && *string == '\0') {
		free(string);
		string = strdup("none");
	}
	if (string == NULL)
		err(1, NULL);

	return string;
}

// escape path and always return a new string so it can be freed
char *
escape_path(char *string)
{
	char *escapedPath = calloc(1, strlen(string) * 4  +  1);
	if (escapedPath == NULL)
		errx(1, "escape_path(): calloc() failed");
	strvis(escapedPath, string, VIS_NL | VIS_CSTYLE | VIS_OCTAL);
	
	return escapedPath;
}

struct ptimebuf {
	uint32_t length;
	attribute_set_t returned_attrs;
	struct timespec st_ptimespec;
} __attribute__((aligned(4), packed));

// ptime is not supported on root filesystems or HFS filesystems older than the feature being introduced
struct timespec
ptime(char *path, int *supported) {
	
	int ret = 0;
	struct ptimebuf buf;
	struct attrlist list = {
		.bitmapcount = ATTR_BIT_MAP_COUNT,
		.commonattr = ATTR_CMN_RETURNED_ATTRS | ATTR_CMN_ADDEDTIME,
	};
	ret = getattrlist(path, &list, &buf, sizeof(buf), FSOPT_NOFOLLOW);
	if (ret) {
		err(1, "ptime: getattrlist");
	}
	
	*supported = 0;
	if (buf.returned_attrs.commonattr & ATTR_CMN_ADDEDTIME) {
		*supported = 1;
	}
	
	return buf.st_ptimespec;
	
}
