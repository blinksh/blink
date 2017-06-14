/*	$NetBSD: mkfifo.c,v 1.8 1997/10/19 05:11:54 lukem Exp $	*/

/*
 * Copyright (c) 1990, 1993
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
__COPYRIGHT("@(#) Copyright (c) 1990, 1993\n\
	The Regents of the University of California.  All rights reserved.\n");
#endif /* not lint */

#ifndef lint
#if 0
static char sccsid[] = "@(#)mkfifo.c	8.2 (Berkeley) 1/5/94";
#endif
__RCSID("$NetBSD: mkfifo.c,v 1.8 1997/10/19 05:11:54 lukem Exp $");
#endif /* not lint */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <err.h>
#ifdef __APPLE__
#include <get_compat.h>
#else 
#define COMPAT_MODE(a,b) (1) 
#endif /* __APPLE__ */ 

int	main __P((int, char **));
static void usage __P((void));

int
main(argc, argv)
	int argc;
	char *argv[];
{
	int ch, exitval;
	void * set;
	mode_t mode = 0;
	int m_used = 0;

	setlocale (LC_ALL, "");

	/* The default mode is the value of the bitwise inclusive or of
	   S_IRUSR, S_IWUSR, S_IRGRP, S_IWGRP, S_IROTH, and S_IWOTH
	   modified by the file creation mask */
	if (!COMPAT_MODE("bin/mkfifo", "Unix2003")) {
		mode = 0666 & ~umask(0);
	}

	while ((ch = getopt(argc, argv, "m:")) != -1)
		switch(ch) {
		case 'm':
			m_used = 1;
			if (!(set = setmode(optarg))) {
				errx(1, "invalid file mode.");
				/* NOTREACHED */
			}
			/* In symbolic mode strings, the + and - operators are
			   interpreted relative to an assumed initial mode of
			   a=rw. */
			mode = getmode (set, 0666);
			break;
		case '?':
		default:
			usage();
		}
//	argc -= optind;
	argv += optind;
	if (argv[0] == NULL)
		usage();

	if (COMPAT_MODE("bin/mkfifo", "Unix2003")) {
		mode_t maskbits = umask(0);	/* now must disable umask so -m mode won't be masked again */
		if (!m_used)
			mode = 0666 & ~maskbits;
	}

	for (exitval = 0; *argv; ++argv) {
		if (mkfifo(*argv, mode) < 0) {
			warn("%s", *argv);
			exitval = 1;
		}
	}
	exit(exitval);
}

void
usage()
{
	(void)fprintf(stderr, "usage: mkfifo [-m mode] fifoname ...\n");
	exit(1);
}
