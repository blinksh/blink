/*
 * Copyright (c) 1988, 1993, 1994
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
__used static const char copyright[] =
"@(#) Copyright (c) 1988, 1993, 1994\n\r\
	The Regents of the University of California.  All rights reserved.\n\r";
#endif /* not lint */

#ifndef lint
#if 0
static char sccsid[] = "@(#)chown.c	8.8 (Berkeley) 4/4/94";
#endif
#endif /* not lint */

#include <sys/cdefs.h>
__RCSID("$FreeBSD: src/usr.sbin/chown/chown.c,v 1.24 2002/07/17 16:22:24 dwmalone Exp $");

#include <sys/param.h>
#include <sys/stat.h>

#include <err.h>
#include <errno.h>
#include <fts.h>
#include <grp.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/time.h>

#ifdef __APPLE__
// #include <get_compat.h>
// #else
#define COMPAT_MODE(a,b) (1)
#endif /* __APPLE__ */

static void	a_gid(const char *);
static void	a_uid(const char *);
static void	chownerr(const char *);
static uid_t	id(const char *, const char *);
static void	usage(void);

static uid_t uid;
static gid_t gid;
static int ischown;
const char *gname;

int
chown_main(int argc, char **argv)
{
	FTS *ftsp;
	FTSENT *p;
	int Hflag, Lflag, Pflag, Rflag, fflag, hflag, vflag;
	int ch, fts_options, rval;
	char *cp;
	int unix2003_compat = 0;
	int symlink_found = 0;

    if (argc < 1) {
		usage();
        return 0; 
    }
	cp = strrchr(argv[0], '/');
	cp = (cp != NULL) ? cp + 1 : argv[0];
	ischown = (strcmp(cp, "chown") == 0);

	Hflag = Lflag = Pflag = Rflag = fflag = hflag = vflag = 0;
	while ((ch = getopt(argc, argv, "HLPRfhv")) != -1)
		switch (ch) {
		case 'H':
			Hflag = 1;
			Lflag = Pflag = 0;
			break;
		case 'L':
			Lflag = 1;
			Hflag = Pflag = 0;
			break;
		case 'P':
			Pflag = 1;
			Hflag = Lflag = 0;
			break;
		case 'R':
			Rflag = 1;
			break;
		case 'f':
			fflag = 1;
			break;
		case 'h':
			hflag = 1;
	 		break;
		case 'v':
			vflag = 1;
			break;
		case '?':
		default:
			usage();
            return 0;
		}
	argv += optind;
	argc -= optind;

    if (argc < 2) {
		usage();
        return 0;
    }
    if (!Rflag && (Hflag || Lflag || Pflag)) {
		warnx("options -H, -L, -P only useful with -R");
        fprintf(stderr, "\r");
    }

	if (Rflag) {
		fts_options = FTS_PHYSICAL;
        if (hflag && (Hflag || Lflag)) {
			warnx("the -R%c and -h options may not be "
			    "specified together", Hflag ? 'H' : 'L');
            fprintf(stderr, "\r");
            return 0;
        }
		if (Hflag)
			fts_options |= FTS_COMFOLLOW;
		else if (Lflag) {
			fts_options &= ~FTS_PHYSICAL;
			fts_options |= FTS_LOGICAL;
		}
	} else
		fts_options = hflag ? FTS_PHYSICAL : FTS_LOGICAL;

	uid = (uid_t)-1;
	gid = (gid_t)-1;
	if (ischown) {
		unix2003_compat = COMPAT_MODE("bin/chown", "Unix2003");
		if ((cp = strchr(*argv, ':')) != NULL) {
			*cp++ = '\0';
			a_gid(cp);
		}
#ifdef SUPPORT_DOT
		else if ((cp = strchr(*argv, '.')) != NULL) {
			warnx("separation of user and group with a period is deprecated");
            fprintf(stderr, "\r");
			*cp++ = '\0';
			a_gid(cp);
		}
#endif
		a_uid(*argv);
	} else {
		unix2003_compat = COMPAT_MODE("bin/chgrp", "Unix2003");
		a_gid(*argv);
	}

    if ((ftsp = fts_open(++argv, fts_options, 0)) == NULL) {
		warn(1, NULL);
        return 0;
    }

	for (rval = 0; (p = fts_read(ftsp)) != NULL;) {
		symlink_found = 0;
		switch (p->fts_info) {
		case FTS_D:			/* Change it at FTS_DP. */
			if (!Rflag)
				fts_set(ftsp, p, FTS_SKIP);
			continue;
		case FTS_DNR:			/* Warn, chown. */
			warnx("%s: %s", p->fts_path, strerror(p->fts_errno));
            fprintf(stderr, "\r");
			rval = 1;
			break;
		case FTS_ERR:			/* Warn, continue. */
		case FTS_NS:
			warnx("%s: %s", p->fts_path, strerror(p->fts_errno));
            fprintf(stderr, "\r");
			rval = 1;
			continue;
		case FTS_SL:
		case FTS_SLNONE:
			/*
			 * The only symlinks that end up here are ones that
			 * don't point to anything and ones that we found
			 * doing a physical walk.
			 */
			if (hflag)
				break;
			else {
				symlink_found = 1;
				if (unix2003_compat) {
					if (Hflag || Lflag) {       /* -H or -L was specified */
						if (p->fts_errno) {
							warnx("%s: %s", p->fts_name, strerror(p->fts_errno));
                            fprintf(stderr, "\r");
							rval = 1;
							continue;
						}
					}
					break; /* Otherwise symlinks keep going */
				}
				continue;
			}
		default:
			break;
		}
		if (unix2003_compat) {
			/* Can only avoid updating times if both uid and gid are -1 */
			if ((uid == (uid_t)-1) && (gid == (gid_t)-1))
				continue;
		} else {
			if ((uid == (uid_t)-1 || uid == p->fts_statp->st_uid) &&
			    (gid == (gid_t)-1 || gid == p->fts_statp->st_gid))
				continue;
		}
		if (((hflag || symlink_found) ? lchown : chown)(p->fts_accpath, uid, gid) == -1) {
			if (!fflag) {
				chownerr(p->fts_path);
				rval = 1;
			}
		} else {
			if (vflag)
				printf("%s\n\r", p->fts_path);
		}
	}
	if (errno)
		err(1, "fts_read");
    return rval;
	// exit(rval);
}

void
a_gid(const char *s)
{
	struct group *gr;

	if (*s == '\0')			/* Argument was "uid[:.]". */
		return;
	gname = s;
	gid = ((gr = getgrnam(s)) != NULL) ? gr->gr_gid : id(s, "group");
}

void
a_uid(const char *s)
{
	struct passwd *pw;

	if (*s == '\0')			/* Argument was "[:.]gid". */
		return;
	uid = ((pw = getpwnam(s)) != NULL) ? pw->pw_uid : id(s, "user");
}

static uid_t
id(const char *name, const char *type)
{
	unsigned long val;
	char *ep;

	errno = 0;
	val = strtoul(name, &ep, 10);
    if (errno || *ep != '\0' || val > UID_MAX) {
		warnx("%s: illegal %s name", name, type);
        fprintf(stderr, "\r");
    }
	return (uid_t)val;
}

void
chownerr(const char *file)
{
	static uid_t euid = -1;
	static int ngroups = -1;
	gid_t groups[NGROUPS_MAX];

	/* Check for chown without being root. */
	if (errno != EPERM || (uid != (uid_t)-1 &&
	    euid == (uid_t)-1 && (euid = geteuid()) != 0)) {
		warn("%s", file);
        fprintf(stderr, "\r");
		return;
	}

	/* Check group membership; kernel just returns EPERM. */
	if (gid != (gid_t)-1 && ngroups == -1 &&
	    euid == (uid_t)-1 && (euid = geteuid()) != 0) {
		ngroups = getgroups(NGROUPS_MAX, groups);
		while (--ngroups >= 0 && gid != groups[ngroups]);
		if (ngroups < 0) {
			warnx("you are not a member of group %s", gname);
            fprintf(stderr, "\r");
			return;
		}
	}
	warn("%s", file);
    fprintf(stderr, "\r");
}

void
usage(void)
{

	if (ischown)
		(void)fprintf(stderr, "\r%s\n\r%s\n\r",
		    "usage: chown [-fhv] [-R [-H | -L | -P]] owner[:group]"
		    " file ...",
		    "       chown [-fhv] [-R [-H | -L | -P]] :group file ...");
	else
		(void)fprintf(stderr, "\r%s\n\r",
		    "usage: chgrp [-fhv] [-R [-H | -L | -P]] group file ...");
	// exit(1);
}
