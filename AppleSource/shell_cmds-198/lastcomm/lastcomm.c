/*	$NetBSD: lastcomm.c,v 1.21 2009/04/12 13:08:31 lukem Exp $	*/

/*
 * Copyright (c) 1980, 1993
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

#include <sys/cdefs.h>
#ifndef lint
__COPYRIGHT("@(#) Copyright (c) 1980, 1993\
 The Regents of the University of California.  All rights reserved.");
#endif /* not lint */

#ifndef lint
#if 0
static char sccsid[] = "@(#)lastcomm.c	8.2 (Berkeley) 4/29/95";
#endif
__RCSID("$NetBSD: lastcomm.c,v 1.21 2009/04/12 13:08:31 lukem Exp $");
#endif /* not lint */

#include <sys/param.h>
#include <sys/stat.h>
#include <sys/acct.h>

#include <ctype.h>
#include <err.h>
#include <fcntl.h>
#include <math.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <struct.h>
#include <time.h>
#include <tzfile.h>
#include <unistd.h>
/* definitions from utmp.h */
#define UT_NAMESIZE     8
#define UT_LINESIZE     8
#include "pathnames.h"

static time_t	 	 expand(u_int);
static char		*flagbits(int);
static const char	*getdev(dev_t);
static int	 	 requested(char *[], struct acct *);
static void	 	 usage(void) __dead;

int	main(int, char **);

int
main(int argc, char *argv[])
{
	char *p;
	struct acct ab;
	struct stat sb;
	FILE *fp;
	off_t size;
	time_t t;
	double delta;
	int ch;
	const char *acctfile = _PATH_ACCT;

	setprogname(argv[0]);

	while ((ch = getopt(argc, argv, "f:")) != -1)
		switch((char)ch) {
		case 'f':
			acctfile = optarg;
			break;
		case '?':
		default:
			usage();
		}
	argc -= optind;
	argv += optind;

	/* Open the file. */
	if ((fp = fopen(acctfile, "r")) == NULL || fstat(fileno(fp), &sb))
		err(1, "%s", acctfile);

	/*
	 * Round off to integral number of accounting records, probably
	 * not necessary, but it doesn't hurt.
	 */
	size = sb.st_size - sb.st_size % sizeof(struct acct);

	/* Check if any records to display. */
	if (size < (off_t)sizeof(struct acct))
		exit(0);

	/*
	 * Seek to before the last entry in the file; use lseek(2) in case
	 * the file is bigger than a "long".
	 */
	size -= sizeof(struct acct);
	if (lseek(fileno(fp), size, SEEK_SET) == -1)
		err(1, "%s", acctfile);

	for (;;) {
		if (fread(&ab, sizeof(struct acct), 1, fp) != 1)
			err(1, "%s", acctfile);

		if (ab.ac_comm[0] == '\0') {
			ab.ac_comm[0] = '?';
			ab.ac_comm[1] = '\0';
		} else
			for (p = &ab.ac_comm[0];
			    p < &ab.ac_comm[fldsiz(acct, ac_comm)] && *p; ++p)
				if (!isprint((unsigned char)*p))
					*p = '?';
		if (!*argv || requested(argv, &ab)) {

			t = expand(ab.ac_utime) + expand(ab.ac_stime);
			(void)printf(
			    "%-*.*s %-7s %-*.*s %-*.*s %6.2f secs %.16s",
			     (int)fldsiz(acct, ac_comm),
			     (int)fldsiz(acct, ac_comm),
			     ab.ac_comm, flagbits(ab.ac_flag),
			     UT_NAMESIZE, UT_NAMESIZE,
			     user_from_uid(ab.ac_uid, 0), UT_LINESIZE,
			     UT_LINESIZE, getdev(ab.ac_tty),
			     t / (double)AHZ, ctime(&ab.ac_btime));
			delta = expand(ab.ac_etime) / (double)AHZ;
			printf(" (%1.0f:%02.0f:%05.2f)\n",
			       floor(delta / SECSPERHOUR),
			       floor(fmod(delta, SECSPERHOUR) / SECSPERMIN),
			       fmod(delta, SECSPERMIN));
		}
		/* are we at the beginning of the file yet? */
		if (size == 0)
			break;
		/* seek backward over the one we read and the next to read */
		if (fseek(fp, 2 * -(long)sizeof(struct acct), SEEK_CUR) == -1)
			err(1, "%s", acctfile);
		/* and account for its size */
		size -= sizeof(struct acct);
	}
	exit(0);
}

static time_t
expand(u_int t)
{
	time_t nt;

	nt = t & 017777;
	t >>= 13;
	while (t) {
		t--;
		nt <<= 3;
	}
	return (nt);
}

static char *
flagbits(int f)
{
	static char flags[20] = "-";
	char *p;

#define	BIT(flag, ch)	if (f & flag) *p++ = ch

	p = flags + 1;
	BIT(ASU, 'S');
	BIT(AFORK, 'F');
	BIT(ACOMPAT, 'C');
	BIT(ACORE, 'D');
	BIT(AXSIG, 'X');
	*p = '\0';
	return (flags);
}

static int
requested(char *argv[], struct acct *acp)
{
	do {
		if (!strcmp(user_from_uid(acp->ac_uid, 0), *argv))
			return (1);
		if (!strcmp(getdev(acp->ac_tty), *argv))
			return (1);
		if (!strncmp(acp->ac_comm, *argv, fldsiz(acct, ac_comm)))
			return (1);
	} while (*++argv);
	return (0);
}

static const char *
getdev(dev_t dev)
{
	static dev_t lastdev = (dev_t)-1;
	static const char *lastname;

	if (dev == NODEV)			/* Special case. */
		return ("__");
	if (dev == lastdev)			/* One-element cache. */
		return (lastname);
	lastdev = dev;
	if ((lastname = devname(dev, S_IFCHR)) == NULL)
		lastname = "??";
	return (lastname);
}

static void
usage(void)
{
	(void)fprintf(stderr,
	    "Usage: %s [ -f file ] [command ...] [user ...] [tty ...]\n",
	    getprogname());
	exit(1);
}
