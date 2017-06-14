/*	$NetBSD: users.c,v 1.7 1998/02/03 04:19:15 perry Exp $	*/

/*
 * Copyright (c) 1980, 1987, 1993
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
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
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

#include <sys/cdefs.h>
#ifndef lint
__COPYRIGHT("@(#) Copyright (c) 1980, 1987, 1993\n\
	The Regents of the University of California.  All rights reserved.\n");
#endif /* not lint */

#ifndef lint
#if 0
static char sccsid[] = "@(#)users.c	8.1 (Berkeley) 6/6/93";
#endif
__RCSID("$NetBSD: users.c,v 1.7 1998/02/03 04:19:15 perry Exp $");
#endif /* not lint */

#include <sys/types.h>

#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <unistd.h>
#include <utmpx.h>

typedef char	namebuf[_UTX_USERSIZE];

int	main __P((int, char **));
int scmp __P((const void *, const void *));

int
main(argc, argv)
	int argc;
	char **argv;
{
	namebuf *names = NULL;
	int ncnt = 0;
	int nmax = 0;
	int cnt;
	struct utmpx *ux;
	int ch;

	while ((ch = getopt(argc, argv, "")) != -1)
		switch(ch) {
		case '?':
		default:
			(void)fprintf(stderr, "usage: users\n");
			exit(1);
		}
	argc -= optind;
	argv += optind;

	setutxent();

	while ((ux = getutxent()) != NULL) {
		if (*ux->ut_user && ux->ut_type == USER_PROCESS)
		{
			if (ncnt >= nmax) {
				nmax += 32;
				names = realloc(names, 
					sizeof (*names) * nmax);

				if (!names) {
					err(1, "realloc");
					/* NOTREACHED */
				}
			}

			(void)strncpy(names[ncnt], ux->ut_user, _UTX_USERSIZE);
			++ncnt;
		}
	}

	if (ncnt) {
		qsort(names, ncnt, _UTX_USERSIZE, scmp);
		(void)printf("%.*s", _UTX_USERSIZE, names[0]);
		for (cnt = 1; cnt < ncnt; ++cnt)
			if (strncmp(names[cnt], names[cnt - 1], _UTX_USERSIZE))
				(void)printf(" %.*s", _UTX_USERSIZE, names[cnt]);
		(void)printf("\n");
	}
	exit(0);
}

int
scmp(p, q)
	const void *p, *q;
{
	return(strncmp((char *) p, (char *) q, _UTX_USERSIZE));
}
