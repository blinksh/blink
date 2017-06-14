/*	$NetBSD: shlock.c,v 1.10 2008/04/28 20:24:14 martin Exp $	*/

/*-
 * Copyright (c) 2006 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Erik E. Fair.
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

/*
** Program to produce reliable locks for shell scripts.
** Algorithm suggested by Peter Honeyman, January 1984,
** in connection with HoneyDanBer UUCP.
**
** I tried extending this to handle shared locks in November 1987,
** and ran into to some fundamental problems:
**
**	Neither 4.3 BSD nor System V have an open(2) with locking,
**	so that you can open a file and have it locked as soon as
**	it's real; you have to make two system calls, and there's
**	a race...
**
**	When removing dead process id's from a list in a file,
**	you need to truncate the file (you don't want to create a
**	new one; see above); unfortunately for the portability of
**	this program, only 4.3 BSD has ftruncate(2).
**
** Erik E. Fair <fair@ucbarpa.berkeley.edu>, November 8, 1987
**
** Extensions for UUCP style locks (i.e. pid is an int in the file,
** rather than an ASCII string). Also fix long standing bug with
** full file systems and temporary files.
**
** Erik E. Fair <fair@apple.com>, November 12, 1989
**
** ANSIfy the code somewhat to make gcc -Wall happy with the code.
** Submit to NetBSD
**
** Erik E. Fair <fair@clock.org>, May 20, 1997
*/

#include <sys/cdefs.h>

#ifndef lint
__RCSID("$NetBSD: shlock.c,v 1.10 2008/04/28 20:24:14 martin Exp $");
#endif

#include <sys/types.h>
#include <sys/file.h>
#include <fcntl.h>			/* Needed on hpux */
#include <stdio.h>
#include <signal.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>

#define	LOCK_SET	0
#define	LOCK_FAIL	1

#define	LOCK_GOOD	0
#define	LOCK_BAD	1

#define	FAIL		(-1)

#define	TRUE	1
#define	FALSE	0

int	Debug = FALSE;
char	*Pname;
const char USAGE[] = "%s: USAGE: %s [-du] [-p PID] -f file\n";
const char E_unlk[] = "%s: unlink(%s): %s\n";
const char E_open[] = "%s: open(%s): %s\n";

#define	dprintf	if (Debug) printf

/*
** Prototypes to make the ANSI compilers happy
** Didn't lint used to do type and argument checking?
** (and wasn't that sufficient?)
*/

/* the following is in case you need to make the prototypes go away. */
char	*xtmpfile(char *, pid_t, int);
int	p_exists(pid_t);
int	cklock(char *, int);
int	mklock(char *, pid_t, int);
void	bad_usage(void);
int	main(int, char **);

/*
** Create a temporary file, all ready to lock with.
** The file arg is so we get the filename right, if he
** gave us a full path, instead of using the current directory
** which might not be in the same filesystem.
*/
char *
xtmpfile(char *file, pid_t pid, int uucpstyle)
{
	int	fd;
	int	len;
	char	*cp, buf[BUFSIZ];
	static char	tempname[BUFSIZ];

	sprintf(buf, "shlock%ld", (u_long)getpid());
	if ((cp = strrchr(strcpy(tempname, file), '/')) != (char *)NULL) {
		*++cp = '\0';
		(void) strcat(tempname, buf);
	} else
		(void) strcpy(tempname, buf);
	dprintf("%s: temporary filename: %s\n", Pname, tempname);

	sprintf(buf, "%ld\n", (u_long)pid);
	len = strlen(buf);
openloop:
	if ((fd = open(tempname, O_RDWR|O_CREAT|O_EXCL, 0644)) < 0) {
		switch(errno) {
		case EEXIST:
			dprintf("%s: file %s exists already.\n",
				Pname, tempname);
			if (unlink(tempname) < 0) {
				fprintf(stderr, E_unlk,
					Pname, tempname, strerror(errno));
				return((char *)NULL);
			}
			/*
			** Further profanity
			*/
			goto openloop;
		default:
			fprintf(stderr, E_open,
				Pname, tempname, strerror(errno));
			return((char *)NULL);
		}
	}

	/*
	** Write the PID into the temporary file before attempting to link
	** to the actual lock file. That way we have a valid lock the instant
	** the link succeeds.
	*/
	if (uucpstyle ?
		(write(fd, &pid, sizeof(pid)) != sizeof(pid)) :
		(write(fd, buf, len) < 0))
	{
		fprintf(stderr, "%s: write(%s,%ld): %s\n",
			Pname, tempname, (u_long)pid, strerror(errno));
		(void) close(fd);
		if (unlink(tempname) < 0) {
			fprintf(stderr, E_unlk,
				Pname, tempname, strerror(errno));
		}
		return((char *)NULL);
	}
	(void) close(fd);
	return(tempname);
}

/*
** Does the PID exist?
** Send null signal to find out.
*/
int
p_exists(pid_t pid)
{
	dprintf("%s: process %ld is ", Pname, (u_long)pid);
	if (pid <= 0) {
		dprintf("invalid\n");
		return(FALSE);
	}
	if (kill(pid, 0) < 0) {
		switch(errno) {
		case ESRCH:
			dprintf("dead\n");
			return(FALSE);	/* pid does not exist */
		case EPERM:
			dprintf("alive\n");
			return(TRUE);	/* pid exists */
		default:
			dprintf("state unknown: %s\n", strerror(errno));
			return(TRUE);	/* be conservative */
		}
	}
	dprintf("alive\n");
	return(TRUE);	/* pid exists */
}

/*
** Check the validity of an existing lock file.
**
**	Read the PID out of the lock
**	Send a null signal to determine whether that PID still exists
**	Existence (or not) determines the validity of the lock.
**
**	Two bigs wins to this algorithm:
**
**	o	Locks do not survive crashes of either the system or the
**			application by any appreciable period of time.
**
**	o	No clean up to do if the system or application crashes.
**
*/
int
cklock(char *file, int uucpstyle)
{
	int	fd = open(file, O_RDONLY);
	ssize_t len;
	pid_t	pid;
	char	buf[BUFSIZ];

	dprintf("%s: checking extant lock <%s>\n", Pname, file);
	if (fd < 0) {
		if (errno != ENOENT)
			fprintf(stderr, E_open, Pname, file, strerror(errno));
		return(TRUE);	/* might or might not; conservatism */
	}

	if (uucpstyle ?
		((len = read(fd, &pid, sizeof(pid))) != sizeof(pid)) :
		((len = read(fd, buf, sizeof(buf))) <= 0))
	{
		close(fd);
		dprintf("%s: lock file format error\n", Pname);
		return(FALSE);
	}
	close(fd);
	buf[len + 1] = '\0';
	return(p_exists(uucpstyle ? pid : atoi(buf)));
}

int
mklock(char *file, pid_t pid, int uucpstyle)
{
	char	*tmp;
	int	retcode = FALSE;

	dprintf("%s: trying lock <%s> for process %ld\n", Pname, file,
	    (u_long)pid);
	if ((tmp = xtmpfile(file, pid, uucpstyle)) == (char *)NULL)
		return(FALSE);

linkloop:
	if (link(tmp, file) < 0) {
		switch(errno) {
		case EEXIST:
			dprintf("%s: lock <%s> already exists\n", Pname, file);
			if (cklock(file, uucpstyle)) {
				dprintf("%s: extant lock is valid\n", Pname);
				break;
			} else {
				dprintf("%s: lock is invalid, removing\n",
					Pname);
				if (unlink(file) < 0) {
					fprintf(stderr, E_unlk,
						Pname, file, strerror(errno));
					break;
				}
			}
			/*
			** I hereby profane the god of structured programming,
			** Edsgar Dijkstra
			*/
			goto linkloop;
		default:
			fprintf(stderr, "%s: link(%s, %s): %s\n",
				Pname, tmp, file, strerror(errno));
			break;
		}
	} else {
		dprintf("%s: got lock <%s>\n", Pname, file);
		retcode = TRUE;
	}
	if (unlink(tmp) < 0) {
		fprintf(stderr, E_unlk, Pname, tmp, strerror(errno));
	}
	return(retcode);
}

void
bad_usage(void)
{
	fprintf(stderr, USAGE, Pname, Pname);
	exit(LOCK_FAIL);
}

int
main(int ac, char **av)
{
	int	x;
	char	*file = (char *)NULL;
	pid_t	pid = 0;
	int	uucpstyle = FALSE;	/* indicating UUCP style locks */
	int	only_check = TRUE;	/* don't make a lock */

	Pname = ((Pname = strrchr(av[0], '/')) ? Pname + 1 : av[0]);

	for(x = 1; x < ac; x++) {
		if (av[x][0] == '-') {
			switch(av[x][1]) {
			case 'u':
				uucpstyle = TRUE;
				break;
			case 'd':
				Debug = TRUE;
				break;
			case 'p':
				if (strlen(av[x]) > 2) {
					pid = atoi(&av[x][2]);
				} else {
					if (++x >= ac) {
						bad_usage();
					}
					pid = atoi(av[x]);
				}
				only_check = FALSE;	/* wants one */
				break;
			case 'f':
				if (strlen(av[x]) > 2) {
					file = &av[x][2];
				} else {
					if (++x >= ac) {
						bad_usage();
					}
					file = av[x];
				}
				break;
			default:
				bad_usage();
			}
		}
	}

	if (file == (char *)NULL || (!only_check && pid <= 0)) {
		bad_usage();
	}

	if (only_check) {
		exit(cklock(file, uucpstyle) ? LOCK_GOOD : LOCK_BAD);
	}

	exit(mklock(file, pid, uucpstyle) ? LOCK_SET : LOCK_FAIL);
}
