/*	$NetBSD: utmpentry.c,v 1.15 2008/07/13 20:07:48 dholland Exp $	*/

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

#include <sys/cdefs.h>
#ifndef lint
__RCSID("$NetBSD: utmpentry.c,v 1.15 2008/07/13 20:07:48 dholland Exp $");
#endif

#include <sys/stat.h>

#include <time.h>
#include <string.h>
#include <err.h>
#include <stdlib.h>
#ifdef __APPLE__
#include <stdint.h>
#endif /* __APPLE__ */

#ifdef SUPPORT_UTMP
#include <utmp.h>
#endif
#ifdef SUPPORT_UTMPX
#include <utmpx.h>
#endif

#include "utmpentry.h"

#ifdef __APPLE__
#define	timespecclear(tsp)	(tsp)->tv_sec = (time_t)((tsp)->tv_nsec = 0L)
#define	timespeccmp(tsp, usp, cmp)					\
	(((tsp)->tv_sec == (usp)->tv_sec) ?				\
	    ((tsp)->tv_nsec cmp (usp)->tv_nsec) :			\
	    ((tsp)->tv_sec cmp (usp)->tv_sec))
#endif /* __APPLE__ */

/* Fail the compile if x is not true, by constructing an illegal type. */
#define COMPILE_ASSERT(x) ((void)sizeof(struct { unsigned : ((x) ? 1 : -1); }))


#ifdef SUPPORT_UTMP
static void getentry(struct utmpentry *, struct utmp *);
static struct timespec utmptime = {0, 0};
#endif
#ifdef SUPPORT_UTMPX
static void getentryx(struct utmpentry *, struct utmpx *);
static struct timespec utmpxtime = {0, 0};
#endif
#if defined(SUPPORT_UTMPX) || defined(SUPPORT_UTMP)
static int setup(const char *);
static void adjust_size(struct utmpentry *e);
#endif

int maxname = 8, maxline = 8, maxhost = 16;
int etype = 1 << USER_PROCESS;
static int numutmp = 0;
static struct utmpentry *ehead;

#if defined(SUPPORT_UTMPX) || defined(SUPPORT_UTMP)
static void
adjust_size(struct utmpentry *e)
{
	int max;

	if ((max = strlen(e->name)) > maxname)
		maxname = max;
	if ((max = strlen(e->line)) > maxline)
		maxline = max;
	if ((max = strlen(e->host)) > maxhost)
		maxhost = max;
}

static int
setup(const char *fname)
{
	int what = 3;
	struct stat st;
	const char *sfname;

	if (fname == NULL) {
#ifdef SUPPORT_UTMPX
		setutxent();
#endif
#ifdef SUPPORT_UTMP
		setutent();
#endif
	} else {
		size_t len = strlen(fname);
		if (len == 0)
			errx(1, "Filename cannot be 0 length.");
#ifdef __APPLE__
		what = 1;
#else /* !__APPLE__ */
		what = fname[len - 1] == 'x' ? 1 : 2;
#endif /* __APPLE__ */
		if (what == 1) {
#ifdef SUPPORT_UTMPX
			if (utmpxname(fname) == 0)
				warnx("Cannot set utmpx file to `%s'",
				    fname);
#else
			warnx("utmpx support not compiled in");
#endif
		} else {
#ifdef SUPPORT_UTMP
			if (utmpname(fname) == 0)
				warnx("Cannot set utmp file to `%s'",
				    fname);
#else
			warnx("utmp support not compiled in");
#endif
		}
	}
#ifdef SUPPORT_UTMPX
	if (what & 1) {
		sfname = fname ? fname : _PATH_UTMPX;
		if (stat(sfname, &st) == -1) {
			warn("Cannot stat `%s'", sfname);
			what &= ~1;
		} else {
			if (timespeccmp(&st.st_mtimespec, &utmpxtime, >))
			    utmpxtime = st.st_mtimespec;
			else
			    what &= ~1;
		}
	}
#endif
#ifdef SUPPORT_UTMP
	if (what & 2) {
		sfname = fname ? fname : _PATH_UTMP;
		if (stat(sfname, &st) == -1) {
			warn("Cannot stat `%s'", sfname);
			what &= ~2;
		} else {
			if (timespeccmp(&st.st_mtimespec, &utmptime, >))
				utmptime = st.st_mtimespec;
			else
				what &= ~2;
		}
	}
#endif
	return what;
}
#endif

void
endutentries(void)
{
	struct utmpentry *ep;

#ifdef SUPPORT_UTMP
	timespecclear(&utmptime);
#endif
#ifdef SUPPORT_UTMPX
	timespecclear(&utmpxtime);
#endif
	ep = ehead;
	while (ep) {
		struct utmpentry *sep = ep;
		ep = ep->next;
		free(sep);
	}
	ehead = NULL;
	numutmp = 0;
}

int
getutentries(const char *fname, struct utmpentry **epp)
{
#ifdef SUPPORT_UTMPX
	struct utmpx *utx;
#endif
#ifdef SUPPORT_UTMP
	struct utmp *ut;
#endif
#if defined(SUPPORT_UTMP) || defined(SUPPORT_UTMPX)
	struct utmpentry *ep;
	int what = setup(fname);
	struct utmpentry **nextp = &ehead;
	switch (what) {
	case 0:
		/* No updates */
		*epp = ehead;
		return numutmp;
	default:
		/* Need to re-scan */
		ehead = NULL;
		numutmp = 0;
	}
#endif

#ifdef SUPPORT_UTMPX
	while ((what & 1) && (utx = getutxent()) != NULL) {
#ifdef __APPLE__
		if (((1 << utx->ut_type) & etype) == 0)
#else /* !__APPLE__ */
		if (fname == NULL && ((1 << utx->ut_type) & etype) == 0)
#endif /* __APPLE__ */
			continue;
		if ((ep = calloc(1, sizeof(struct utmpentry))) == NULL) {
			warn(NULL);
			return 0;
		}
		getentryx(ep, utx);
		*nextp = ep;
		nextp = &(ep->next);
	}
#endif

#ifdef SUPPORT_UTMP
	if ((etype & (1 << USER_PROCESS)) != 0) {
		while ((what & 2) && (ut = getutent()) != NULL) {
			if (fname == NULL && (*ut->ut_name == '\0' ||
			    *ut->ut_line == '\0'))
				continue;
			/* Don't process entries that we have utmpx for */
			for (ep = ehead; ep != NULL; ep = ep->next) {
				if (strncmp(ep->line, ut->ut_line,
				    sizeof(ut->ut_line)) == 0)
					break;
			}
			if (ep != NULL)
				continue;
			if ((ep = calloc(1, sizeof(*ep))) == NULL) {
				warn(NULL);
				return 0;
			}
			getentry(ep, ut);
			*nextp = ep;
			nextp = &(ep->next);
		}
	}
#endif
	numutmp = 0;
#if defined(SUPPORT_UTMP) || defined(SUPPORT_UTMPX)
	if (ehead != NULL) {
		struct utmpentry *from = ehead, *save;
		
		ehead = NULL;
		while (from != NULL) {
			for (nextp = &ehead;
			    (*nextp) && strcmp(from->line, (*nextp)->line) > 0;
			    nextp = &(*nextp)->next)
				continue;
			save = from;
			from = from->next;
			save->next = *nextp;
			*nextp = save;
			numutmp++;
		}
	}
	*epp = ehead;
	return numutmp;
#else
	*epp = NULL;
	return 0;
#endif
}

#ifdef SUPPORT_UTMP
static void
getentry(struct utmpentry *e, struct utmp *up)
{
	COMPILE_ASSERT(sizeof(e->name) > sizeof(up->ut_name));
	COMPILE_ASSERT(sizeof(e->line) > sizeof(up->ut_line));
	COMPILE_ASSERT(sizeof(e->host) > sizeof(up->ut_host));

	/*
	 * e has just been calloc'd. We don't need to clear it or
	 * append null-terminators, because its length is strictly
	 * greater than the source string. Use strncpy to _read_
	 * up->ut_* because they may not be terminated. For this
	 * reason we use the size of the _source_ as the length
	 * argument.
	 */
	(void)strncpy(e->name, up->ut_name, sizeof(up->ut_name));
	(void)strncpy(e->line, up->ut_line, sizeof(up->ut_line));
	(void)strncpy(e->host, up->ut_host, sizeof(up->ut_host));

	e->tv.tv_sec = up->ut_time;
	e->tv.tv_usec = 0;
	e->pid = 0;
	e->term = 0;
	e->exit = 0;
	e->sess = 0;
	e->type = USER_PROCESS;
	adjust_size(e);
}
#endif

#ifdef SUPPORT_UTMPX
static void
getentryx(struct utmpentry *e, struct utmpx *up)
{
	COMPILE_ASSERT(sizeof(e->name) > sizeof(up->ut_name));
	COMPILE_ASSERT(sizeof(e->line) > sizeof(up->ut_line));
	COMPILE_ASSERT(sizeof(e->host) > sizeof(up->ut_host));

	/*
	 * e has just been calloc'd. We don't need to clear it or
	 * append null-terminators, because its length is strictly
	 * greater than the source string. Use strncpy to _read_
	 * up->ut_* because they may not be terminated. For this
	 * reason we use the size of the _source_ as the length
	 * argument.
	 */
	(void)strncpy(e->name, up->ut_name, sizeof(up->ut_name));
	(void)strncpy(e->line, up->ut_line, sizeof(up->ut_line));
	(void)strncpy(e->host, up->ut_host, sizeof(up->ut_host));

	e->tv = up->ut_tv;
	e->pid = up->ut_pid;
#ifndef __APPLE__
	e->term = up->ut_exit.e_termination;
	e->exit = up->ut_exit.e_exit;
	e->sess = up->ut_session;
#endif /* !__APPLE__ */
	e->type = up->ut_type;
	adjust_size(e);
}
#endif
