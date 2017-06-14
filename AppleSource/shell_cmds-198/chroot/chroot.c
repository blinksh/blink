/*
 * Copyright (c) 1988, 1993
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
__COPYRIGHT("@(#) Copyright (c) 1988, 1993\n\
	The Regents of the University of California.  All rights reserved.\n");
#endif /* not lint */

#ifndef lint
#if 0
static char sccsid[] = "@(#)chroot.c	8.1 (Berkeley) 6/9/93";
#else
__RCSID("$NetBSD: chroot.c,v 1.7 1998/10/06 03:47:51 mrg Exp $");
#endif
#endif /* not lint */

#include <sys/param.h>

#include <ctype.h>
#include <err.h>
#include <errno.h>
#include <grp.h>
#include <paths.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int	main __P((int, char **));
void	usage __P((void)) __attribute__((__noreturn__));

char	*user;		/* user to switch to before running program */
char	*group;		/* group to switch to ... */
char	*grouplist;	/* group list to switch to ... */

int
main(argc, argv)
	int argc;
	char *argv[];
{
	struct group *gp;
	struct passwd *pw;
	char *shell, *endp, *comma;
	gid_t gid = 0, gidlist[NGROUPS_MAX];
	uid_t uid = 0;
	int ch, gids;

	while ((ch = getopt(argc, argv, "G:g:u:")) != -1)
		switch(ch) {
		case 'u':
			user = optarg;
			break;
		case 'g':
			group = optarg;
			break;
		case 'G':
			grouplist = optarg;
			break;
		case '?':
		default:
			usage();
		}
	argc -= optind;
	argv += optind;

	if (argc < 1)
		usage();

	if (group) {
		if (isdigit(*group)) {
			gid = (gid_t)strtol(group, &endp, 0);
			if (endp == group)
				goto getgroup;
		} else {
getgroup:
			if ((gp = getgrnam(group)))
				gid = gp->gr_gid;
			else
				errx(1, "no such group %s", group);
		}
	}

	for (gids = 0; grouplist; ) {
		comma = strchr(grouplist, ',');

		if (comma)
			*comma++ = '\0';

		if (isdigit(*grouplist)) {
			gidlist[gids] = (gid_t)strtol(grouplist, &endp, 0);
			if (endp == grouplist)
				goto getglist;
		} else {
getglist:
			if ((gp = getgrnam(grouplist)))
				gidlist[gids] = gp->gr_gid;
			else
				errx(1, "no such group %s", group);
		}
		gids++;
		grouplist = comma;
	}

	if (user) {
		if (isdigit(*user)) {
			uid = (uid_t)strtol(user, &endp, 0);
			if (endp == user)
				goto getuser;
		} else {
getuser:
			if ((pw = getpwnam(user)))
				uid = pw->pw_uid;
			else
				errx(1, "no such user %s", user);
		}
	}

	if (chdir(argv[0]) || chroot("."))
		err(1, "%s", argv[0]);

	if (gids && setgroups(gids, gidlist) < 0)
		err(1, "setgroups");
	if (group && setgid(gid) < 0)
		err(1, "setgid");
	if (user && setuid(uid) < 0)
		err(1, "setuid");

	if (argv[1]) {
		execvp(argv[1], &argv[1]);
		err(1, "%s", argv[1]);
	}

	if (!(shell = getenv("SHELL")))
		shell = _PATH_BSHELL;
	execlp(shell, shell, "-i", NULL);
	err(1, "%s", shell);
	/* NOTREACHED */
}

void
usage()
{
	(void)fprintf(stderr, "usage: chroot [-g group] [-G group,group,...] "
	    "[-u user] newroot [command]\n");
	exit(1);
}
