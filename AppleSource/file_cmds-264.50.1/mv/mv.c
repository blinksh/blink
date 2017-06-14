/*
 * Copyright (c) 1989, 1993, 1994
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Ken Smith of The State University of New York at Buffalo.
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
__used static char const copyright[] =
"@(#) Copyright (c) 1989, 1993, 1994\n\r\
	The Regents of the University of California.  All rights reserved.\n\r";
#endif /* not lint */

#ifndef lint
#if 0
static char sccsid[] = "@(#)mv.c	8.2 (Berkeley) 4/2/94";
#endif
#endif /* not lint */
#include <sys/cdefs.h>
__RCSID("$FreeBSD: src/bin/mv/mv.c,v 1.39 2002/07/09 17:45:13 johan Exp $");

#include <sys/param.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <sys/mount.h>

#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <grp.h>
#include <limits.h>
#include <paths.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sysexits.h>
#include <unistd.h>

#ifdef __APPLE__
#include <copyfile.h>
#include <sys/mount.h>
#endif

#ifdef __APPLE__ 
// #include <get_compat.h>
// #else
#define COMPAT_MODE(a,b) (1) 
#endif /* __APPLE__ */ 

#include "pathnames.h"

int fflg, iflg, nflg, vflg;

static int	copy(char *, char *);
static int	do_move(char *, char *);
static int	fastcopy(char *, char *, struct stat *);
static void	usage(void);

int
mv_main(int argc, char *argv[])
{
	size_t baselen, len;
	int rval;
	char *p, *endp;
	struct stat sb;
#ifdef __APPLE__
	struct stat fsb, tsb;
#endif /* __APPLE__ */
	int ch;
	char path[PATH_MAX];

	while ((ch = getopt(argc, argv, "finv")) != -1)
		switch (ch) {
		case 'i':
			iflg = 1;
			fflg = nflg = 0;
			break;
		case 'f':
			fflg = 1;
			iflg = nflg = 0;
			break;
		case 'n':
			nflg = 1;
			fflg = iflg = 0;
			break;
		case 'v':
			vflg = 1;
			break;
		default:
			usage();
            return 0;
		}
	argc -= optind;
	argv += optind;

    if (argc < 2) {
		usage();
        return 0;
    }

	/*
	 * If the stat on the target fails or the target isn't a directory,
	 * try the move.  More than 2 arguments is an error in this case.
	 */
	if (stat(argv[argc - 1], &sb) || !S_ISDIR(sb.st_mode)) {
        if (argc > 2) {
			usage();
            return 0;
        }
        return (do_move(argv[0], argv[1]));
		// exit(do_move(argv[0], argv[1]));
	}
	
#ifdef __APPLE__
	if (argc == 2 && !lstat(argv[0], &fsb) && !lstat(argv[1], &tsb) &&
		fsb.st_ino == tsb.st_ino && fsb.st_dev == tsb.st_dev &&
		fsb.st_gen == tsb.st_gen) {
		/*
		 * We appear to be trying to move a directory into itself,
		 * but it may be that the filesystem is case insensitive and
		 * we are trying to rename the directory to a case-variant.
		 * Ignoring trailing slashes, we look for any difference in
		 * the directory names.  If there is a difference we do
		 * the rename, otherwise we fall-thru to the traditional
		 * error.  Note the lstat calls above (rather than stat)
		 * permit the renaming of symlinks to case-variants.
		 */
		char *q;
		
		for (p = argv[0] + strlen(argv[0]); p != argv[0]; ) {
			p--;
			if (*p != '/')
				break;
		}
		for (q = argv[1] + strlen(argv[1]); q != argv[1]; ) {
			q--;
			if (*q != '/')
				break;
		}
		for ( ; ; p--, q--) {
			if (*p != *q)
                return(do_move(argv[0], argv[1]));
				// exit(do_move(argv[0], argv[1]));
			if (*p == '/')
				break;
			if (p == argv[0]) {
				if (q == argv[1] || *(q-1) == '/')
					break;
                return(do_move(argv[0], argv[1]));
				// exit(do_move(argv[0], argv[1]));
			}
			if (q == argv[1]) {
				if (p == argv[0] || *(p-1) == '/')
					break;
                return(do_move(argv[0], argv[1]));
//				exit(do_move(argv[0], argv[1]));
			}
		}
	}
#endif /* __APPLE__ */

	/* It's a directory, move each file into it. */
	if (strlen(argv[argc - 1]) > sizeof(path) - 1)
		errx(1, "%s: destination pathname too long", *argv);
	(void)strcpy(path, argv[argc - 1]);
	baselen = strlen(path);
	endp = &path[baselen];
	if (!baselen || *(endp - 1) != '/') {
		*endp++ = '/';
		++baselen;
	}
	for (rval = 0; --argc; ++argv) {
		/*
		 * Find the last component of the source pathname.  It
		 * may have trailing slashes.
		 */
		p = *argv + strlen(*argv);
		while (p != *argv && p[-1] == '/')
			--p;
		while (p != *argv && p[-1] != '/')
			--p;

		if ((baselen + (len = strlen(p))) >= PATH_MAX) {
			warnx("%s: destination pathname too long", *argv);
            fprintf(stderr, "\r");
			rval = 1;
		} else {
			memmove(endp, p, (size_t)len + 1);
			if (COMPAT_MODE("bin/mv", "unix2003")) {
				/* 
				 * For Unix 2003 compatibility, check if old and new are 
				 * same file, and produce an error * (like on Sun) that 
				 * conformance test 66 in mv.ex expects.
				 */
				if (!stat(*argv, &fsb) && !stat(path, &tsb) &&
					fsb.st_ino == tsb.st_ino && 
					fsb.st_dev == tsb.st_dev &&
					fsb.st_gen == tsb.st_gen) {
					(void)fprintf(stderr, "mv: %s and %s are identical\n\r", 
								*argv, path);
					rval = 2; /* Like the Sun */
				} else {
					if (do_move(*argv, path))
						rval = 1;
				}
			} else {
				if (do_move(*argv, path))
					rval = 1;
			}
		}
	}
    return(rval);
	// exit(rval);
}

int
do_move(char *from, char *to)
{
	struct stat sb;
	int ask, ch, first;
	char modep[15];

	/*
	 * Check access.  If interactive and file exists, ask user if it
	 * should be replaced.  Otherwise if file exists but isn't writable
	 * make sure the user wants to clobber it.
	 */
	if (!fflg && !access(to, F_OK)) {

		/* prompt only if source exist */
	        if (lstat(from, &sb) == -1) {
			warn("%s", from);
            fprintf(stderr, "\r");
			return (1);
		}

#define YESNO "(y/n [n]) "
		ask = 0;
		if (nflg) {
			if (vflg)
				printf("%s not overwritten\n\r", to);
			return (0);
		} else if (iflg) {
			(void)fprintf(stderr, "overwrite %s? %s", to, YESNO);
			ask = 1;
		} else if (access(to, W_OK) && !stat(to, &sb)) {
			strmode(sb.st_mode, modep);
			(void)fprintf(stderr, "override %s%s%s/%s for %s? %s",
			    modep + 1, modep[9] == ' ' ? "" : " ",
			    user_from_uid(sb.st_uid, 0),
			    group_from_gid(sb.st_gid, 0), to, YESNO);
			ask = 1;
		}
		if (ask) {
			first = ch = getchar();
			while (ch != '\n\r' && ch != EOF)
				ch = getchar();
			if (first != 'y' && first != 'Y') {
				(void)fprintf(stderr, "not overwritten\n\r");
				return (0);
			}
		}
	}
	if (!rename(from, to)) {
		if (vflg)
			printf("%s -> %s\n\r", from, to);
		return (0);
	}

	if (errno == EXDEV) {
		struct statfs sfs;
		char path[PATH_MAX];

		/* Can't mv(1) a mount point. */
		if (realpath(from, path) == NULL) {
			warnx("cannot resolve %s: %s", from, path);
            fprintf(stderr, "\r");
			return (1);
		}
		if (!statfs(path, &sfs) && !strcmp(path, sfs.f_mntonname)) {
			warnx("cannot rename a mount point");
            fprintf(stderr, "\r");
			return (1);
		}
	} else {
		warn("rename %s to %s", from, to);
        fprintf(stderr, "\r");
		return (1);
	}

	/*
	 * If rename fails because we're trying to cross devices, and
	 * it's a regular file, do the copy internally; otherwise, use
	 * cp and rm.
	 */
	if (lstat(from, &sb)) {
		warn("%s", from);
        fprintf(stderr, "\r");
		return (1);
	}
	return (S_ISREG(sb.st_mode) ?
	    fastcopy(from, to, &sb) : copy(from, to));
}

int
fastcopy(char *from, char *to, struct stat *sbp)
{
	struct timeval tval[2];
	static u_int blen;
	static char *bp;
	mode_t oldmode;
	ssize_t nread;
	int from_fd, to_fd;

	if ((from_fd = open(from, O_RDONLY, 0)) < 0) {
		warn("%s", from);
        fprintf(stderr, "\r");
		return (1);
	}
	if (blen < sbp->st_blksize) {
		if (bp != NULL)
			free(bp);
		if ((bp = malloc((size_t)sbp->st_blksize)) == NULL) {
			blen = 0;
			warnx("malloc failed");
            fprintf(stderr, "\r");
			return (1);
		}
		blen = sbp->st_blksize;
	}
	while ((to_fd =
	    open(to, O_CREAT | O_EXCL | O_TRUNC | O_WRONLY, 0)) < 0) {
		if (errno == EEXIST && unlink(to) == 0)
			continue;
		warn("%s", to);
        fprintf(stderr, "\r");
		(void)close(from_fd);
		return (1);
	}
#ifdef __APPLE__
       {
               struct statfs sfs;

               /*
                * Pre-allocate blocks for the destination file if it
                * resides on Xsan.
                */
               if (fstatfs(to_fd, &sfs) == 0 &&
                   strcmp(sfs.f_fstypename, "acfs") == 0) {
                       fstore_t fst;

                       fst.fst_flags = 0;
                       fst.fst_posmode = F_PEOFPOSMODE;
                       fst.fst_offset = 0;
                       fst.fst_length = sbp->st_size;

                       (void) fcntl(to_fd, F_PREALLOCATE, &fst);
               }
       }
#endif /* __APPLE__ */
	while ((nread = read(from_fd, bp, (size_t)blen)) > 0)
		if (write(to_fd, bp, (size_t)nread) != nread) {
			warn("%s", to);
            fprintf(stderr, "\r");
			goto err;
		}
	if (nread < 0) {
		warn("%s", from);
        fprintf(stderr, "\r");
    err:		if (unlink(to)) {
			warn("%s: remove", to);
            fprintf(stderr, "\r");
    }
(void)close(from_fd);
		(void)close(to_fd);
		return (1);
	}
#ifdef __APPLE__
	/* XATTR can fail if to_fd has mode 000 */
	if (fcopyfile(from_fd, to_fd, NULL, COPYFILE_ACL | COPYFILE_XATTR) < 0) {
		warn("%s: unable to move extended attributes and ACL from %s",
		     to, from);
        fprintf(stderr, "\r");
}
#endif
	(void)close(from_fd);

	oldmode = sbp->st_mode & ALLPERMS;
	if (fchown(to_fd, sbp->st_uid, sbp->st_gid)) {
		warn("%s: set owner/group (was: %lu/%lu)", to,
		    (u_long)sbp->st_uid, (u_long)sbp->st_gid);
        fprintf(stderr, "\r");
		if (oldmode & (S_ISUID | S_ISGID)) {
			warnx(
"%s: owner/group changed; clearing suid/sgid (mode was 0%03o)",
			    to, oldmode);
            fprintf(stderr, "\r");
			sbp->st_mode &= ~(S_ISUID | S_ISGID);
		}
	}
    if (fchmod(to_fd, sbp->st_mode)) {
		warn("%s: set mode (was: 0%03o)", to, oldmode);
        fprintf(stderr, "\r");
    }
	/*
	 * XXX
	 * NFS doesn't support chflags; ignore errors unless there's reason
	 * to believe we're losing bits.  (Note, this still won't be right
	 * if the server supports flags and we were trying to *remove* flags
	 * on a file that we copied, i.e., that we didn't create.)
	 */
	errno = 0;
	if (fchflags(to_fd, (u_int)sbp->st_flags))
        if (errno != ENOTSUP || sbp->st_flags != 0) {
			warn("%s: set flags (was: 0%07o)", to, sbp->st_flags);
            fprintf(stderr, "\r");
        }

	tval[0].tv_sec = sbp->st_atime;
	tval[1].tv_sec = sbp->st_mtime;
	tval[0].tv_usec = tval[1].tv_usec = 0;
    if (utimes(to, tval)) {
		warn("%s: set times", to);
        fprintf(stderr, "\r");
    }
	if (close(to_fd)) {
		warn("%s", to);
        fprintf(stderr, "\r");
		return (1);
	}

	if (unlink(from)) {
		warn("%s: remove", from);
        fprintf(stderr, "\r");
		return (1);
	}
	if (vflg)
		printf("%s -> %s\n\r", from, to);
	return (0);
}

int
copy(char *from, char *to)
{
	int pid, status;
	
	/* posix_spawn cp from to && rm from */

	if ((pid = fork()) == 0) {
		execl(_PATH_CP, "mv", vflg ? "-PRpv" : "-PRp", "--", from, to,
		    (char *)NULL);
		warn("%s", _PATH_CP);
        fprintf(stderr, "\r");
        return -1;
		// _exit(1);
	}
	if (waitpid(pid, &status, 0) == -1) {
		warn("%s: waitpid", _PATH_CP);
        fprintf(stderr, "\r");
		return (1);
	}
	if (!WIFEXITED(status)) {
		warnx("%s: did not terminate normally", _PATH_CP);
        fprintf(stderr, "\r");
		return (1);
	}
	if (WEXITSTATUS(status)) {
		warnx("%s: terminated with %d (non-zero) status",
		    _PATH_CP, WEXITSTATUS(status));
        fprintf(stderr, "\r");
		return (1);
	}
	if (!(pid = vfork())) {
		execl(_PATH_RM, "mv", "-rf", "--", from, (char *)NULL);
		warn("%s", _PATH_RM);
        fprintf(stderr, "\r");
        return -1;
		// _exit(1);
	}
	if (waitpid(pid, &status, 0) == -1) {
		warn("%s: waitpid", _PATH_RM);
        fprintf(stderr, "\r");
		return (1);
	}
	if (!WIFEXITED(status)) {
		warnx("%s: did not terminate normally", _PATH_RM);
		return (1);
	}
	if (WEXITSTATUS(status)) {
		warnx("%s: terminated with %d (non-zero) status",
		    _PATH_RM, WEXITSTATUS(status));
        fprintf(stderr, "\r");
		return (1);
	}
	return (0);
}

void
usage(void)
{

	(void)fprintf(stderr, "\r%s\n\r%s\n\r",
		      "usage: mv [-f | -i | -n] [-v] source target",
		      "       mv [-f | -i | -n] [-v] source ... directory");
	// exit(EX_USAGE);
}
