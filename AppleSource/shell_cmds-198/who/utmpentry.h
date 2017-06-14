/*	$NetBSD: utmpentry.h,v 1.7 2008/07/13 20:07:49 dholland Exp $	*/

/*-
 * Copyright (c) 2002 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Christos Zoulas.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#if defined(SUPPORT_UTMPX)
# include <utmpx.h>
# define WHO_NAME_LEN		_UTX_USERSIZE
# define WHO_LINE_LEN		_UTX_LINESIZE
# define WHO_HOST_LEN		_UTX_HOSTSIZE
#elif defined(SUPPORT_UTMP)
# include <utmp.h>
# define WHO_NAME_LEN		UT_NAMESIZE
# define WHO_LINE_LEN		UT_LINESIZE
# define WHO_HOST_LEN		UT_HOSTSIZE
#else
# error Either SUPPORT_UTMPX or SUPPORT_UTMP must be defined!
#endif


struct utmpentry {
	char name[WHO_NAME_LEN + 1];
	char line[WHO_LINE_LEN + 1];
	char host[WHO_HOST_LEN + 1];
	struct timeval tv;
	pid_t pid;
#ifndef __APPLE__
	uint16_t term;
	uint16_t exit;
	uint16_t sess;
#endif /* !__APPLE__ */
	uint16_t type;
	struct utmpentry *next;
};

extern int maxname, maxline, maxhost;
extern int etype;

/*
 * getutentries provides a linked list of struct utmpentry and returns
 * the number of entries. The first argument, if not null, names an 
 * alternate utmp(x) file to look in.
 *
 * The memory returned by getutentries belongs to getutentries. The
 * list returned (or elements of it) may be returned again later if
 * utmp hasn't changed in the meantime.
 *
 * endutentries clears and frees the cached data.
 */

int getutentries(const char *, struct utmpentry **);
void endutentries(void);
