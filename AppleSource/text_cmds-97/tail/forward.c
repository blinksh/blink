/*-
 * Copyright (c) 1991, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Edward Sze-Tyan Wang.
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

__FBSDID("$FreeBSD$");

#ifndef lint
static const char sccsid[] = "@(#)forward.c	8.1 (Berkeley) 6/6/93";
#endif

#include <sys/param.h>
#include <sys/mount.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/mman.h>
#include <sys/event.h>

#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "extern.h"

static void rlines(FILE *, off_t, struct stat *);
static void show(file_info_t *);
static void set_events(file_info_t *files);

/* defines for inner loop actions */
#define USE_SLEEP	0
#define USE_KQUEUE	1
#define ADD_EVENTS	2

struct kevent *ev;
int action = USE_SLEEP;
int kq;

static const file_info_t *last;

/*
 * forward -- display the file, from an offset, forward.
 *
 * There are eight separate cases for this -- regular and non-regular
 * files, by bytes or lines and from the beginning or end of the file.
 *
 * FBYTES	byte offset from the beginning of the file
 *	REG	seek
 *	NOREG	read, counting bytes
 *
 * FLINES	line offset from the beginning of the file
 *	REG	read, counting lines
 *	NOREG	read, counting lines
 *
 * RBYTES	byte offset from the end of the file
 *	REG	seek
 *	NOREG	cyclically read characters into a wrap-around buffer
 *
 * RLINES
 *	REG	mmap the file and step back until reach the correct offset.
 *	NOREG	cyclically read lines into a wrap-around array of buffers
 */
void
forward(FILE *fp, enum STYLE style, off_t off, struct stat *sbp)
{
	int ch;

	switch(style) {
	case FBYTES:
		if (off == 0)
			break;
		if (S_ISREG(sbp->st_mode)) {
			if (sbp->st_size < off)
				off = sbp->st_size;
			if (fseeko(fp, off, SEEK_SET) == -1) {
				ierr();
				return;
			}
		} else while (off--)
			if ((ch = getc(fp)) == EOF) {
				if (ferror(fp)) {
					ierr();
					return;
				}
				break;
			}
		break;
	case FLINES:
		if (off == 0)
			break;
		for (;;) {
			if ((ch = getc(fp)) == EOF) {
				if (ferror(fp)) {
					ierr();
					return;
				}
				break;
			}
			if (ch == '\n' && !--off)
				break;
		}
		break;
	case RBYTES:
		if (S_ISREG(sbp->st_mode)) {
			if (sbp->st_size >= off &&
			    fseeko(fp, -off, SEEK_END) == -1) {
				ierr();
				return;
			}
		} else if (off == 0) {
			while (getc(fp) != EOF);
			if (ferror(fp)) {
				ierr();
				return;
			}
		} else
			if (bytes(fp, off))
				return;
		break;
	case RLINES:
		if (S_ISREG(sbp->st_mode))
			if (!off) {
				if (fseeko(fp, (off_t)0, SEEK_END) == -1) {
					ierr();
					return;
				}
			} else
				rlines(fp, off, sbp);
		else if (off == 0) {
			while (getc(fp) != EOF);
			if (ferror(fp)) {
				ierr();
				return;
			}
		} else
			if (lines(fp, off))
				return;
		break;
	default:
		break;
	}

	while ((ch = getc(fp)) != EOF)
		if (putchar(ch) == EOF)
			oerr();
	if (ferror(fp)) {
		ierr();
		return;
	}
	(void)fflush(stdout);
}

/*
 * rlines -- display the last offset lines of the file.
 */
static void
rlines(fp, off, sbp)
	FILE *fp;
	off_t off;
	struct stat *sbp;
{
#ifdef __APPLE__
	/* Using mmap on network filesystems can frequently lead
	to distress, and even on local file systems other processes
	truncating the file can also lead to upset. */

	/* Seek to sbp->st_blksize before the end of the file, find
	all the newlines.   If there are enough, print the last off
	lines.  Otherwise go back another sbp->st_blksize bytes,
	and count newlines.  Avoid re-reading blocks when possible. */

	// +1 because we capture line ends and we want off line _starts_,
	// +1 because the first line might be partial when try_at != 0
	off_t search_for = off +2;
	off_t try_at = sbp->st_size;
	off_t last_try = sbp->st_size;
	off_t found_this_pass = 0;
	off_t found_total = 0;
	off_t *found_at = calloc(search_for, sizeof(off_t));

	flockfile(fp);

	if (found_at == NULL) {
		ierr();
		goto done;
	}

	if (off == 0 || sbp->st_size == 0) {
		goto done;
	}

	/* The last character is special.  Check to make sure that it is a \n,
	 * and if not, subtract one from the number of \n we need to search for.
	 */
	if (0 != fseeko(fp, sbp->st_size - 1, SEEK_SET)) {
		ierr();
		goto done;
	}
	if ('\n' != getc_unlocked(fp)) {
		search_for--;
	}

	while(try_at != 0) {
		found_this_pass = 0;

		if (try_at < sbp->st_blksize) {
			found_at[found_this_pass++] = 0;
			try_at = 0;
		} else {
			last_try = try_at;
			try_at -= sbp->st_blksize;
		}

		if (0 != fseeko(fp, try_at, SEEK_SET)) {
			ierr();
			goto done;
		}

		char ch;
		while(EOF != (ch = getc_unlocked(fp))) {
			if (ch == '\n') {
				found_at[found_this_pass++ % search_for] = ftello(fp);
				found_total++;
			}
			if (ftello(fp) == last_try && found_total < search_for) {
				// We just reached the last block we scanned,
				// and we know there arn't enough lines found
				// so far to be happy, so we don't have to
				// read it again.
				break;
			}
		}

		if (found_this_pass >= search_for || try_at == 0) {
			off_t min = found_at[0];
			int min_i = 0;
			int i;
			int lim = (found_this_pass < search_for) ? found_this_pass : search_for;
			for(i = 1; i < lim; i++) {
				if (found_at[i] < min) {
					min = found_at[i];
					min_i = i;
				}
			}

			off_t target = min;

			if (found_this_pass >= search_for) {
				// min_i might be a partial line (unless
				// try_at is 0).   If we  found search_for
				// lines, min_i+1 is the first known full line
				// _and_ because we look for an extra line we
				// don't need to show it.
				target = found_at[(min_i + 1) % search_for];
			}

			if (0 != fseeko(fp, target, SEEK_SET)) {
				ierr();
				goto done;
			}

			flockfile(stdout);
			while(EOF != (ch = getc_unlocked(fp))) {
				if (EOF == putchar_unlocked(ch)) {
					funlockfile(stdout);
					oerr();
					goto done;
				}
			}
			funlockfile(stdout);
			goto done;
		}
	}

done:
	funlockfile(fp);
	free(found_at);
	return;
#else
	struct mapinfo map;
	off_t curoff, size;
	int i;

	if (!(size = sbp->st_size))
		return;
	map.start = NULL;
	map.fd = fileno(fp);
	map.mapoff = map.maxoff = size;

	/*
	 * Last char is special, ignore whether newline or not. Note that
	 * size == 0 is dealt with above, and size == 1 sets curoff to -1.
	 */
	curoff = size - 2;
	while (curoff >= 0) {
		if (curoff < map.mapoff && maparound(&map, curoff) != 0) {
			ierr();
			return;
		}
		for (i = curoff - map.mapoff; i >= 0; i--)
			if (map.start[i] == '\n' && --off == 0)
				break;
		/* `i' is either the map offset of a '\n', or -1. */
		curoff = map.mapoff + i;
		if (i >= 0)
			break;
	}
	curoff++;
	if (mapprint(&map, curoff, size - curoff) != 0) {
		ierr();
		exit(1);
	}

	/* Set the file pointer to reflect the length displayed. */
	if (fseeko(fp, sbp->st_size, SEEK_SET) == -1) {
		ierr();
		return;
	}
	if (map.start != NULL && munmap(map.start, map.maplen)) {
		ierr();
		return;
	}
#endif
}

static void
show(file_info_t *file)
{
    int ch;

    while ((ch = getc(file->fp)) != EOF) {
	if (last != file && no_files > 1) {
		if (!qflag)
			(void)printf("\n==> %s <==\n", file->file_name);
		last = file;
	}
	if (putchar(ch) == EOF)
		oerr();
    }
    (void)fflush(stdout);
    if (ferror(file->fp)) {
	    file->fp = NULL;
	    fname = file->file_name;
	    ierr();
	    fname = NULL;
    } else
	    clearerr(file->fp);
}

static void
set_events(file_info_t *files)
{
	int i, n = 0;
	file_info_t *file;
	struct timespec ts;
	struct statfs sf;

	ts.tv_sec = 0;
	ts.tv_nsec = 0;

	action = USE_KQUEUE;
	for (i = 0, file = files; i < no_files; i++, file++) {
		if (! file->fp)
			continue;

		if (fstatfs(fileno(file->fp), &sf) == 0 &&
		    (sf.f_flags & MNT_LOCAL) == 0) {
			action = USE_SLEEP;
			return;
		}

		if (Fflag && fileno(file->fp) != STDIN_FILENO) {
			EV_SET(&ev[n], fileno(file->fp), EVFILT_VNODE,
			    EV_ADD | EV_ENABLE | EV_CLEAR,
			    NOTE_DELETE | NOTE_RENAME, 0, 0);
			n++;
		}
		EV_SET(&ev[n], fileno(file->fp), EVFILT_READ,
		    EV_ADD | EV_ENABLE | EV_CLEAR, 0, 0, 0);
		n++;
	}

	if (kevent(kq, ev, n, NULL, 0, &ts) < 0) {
		action = USE_SLEEP;
	}
}

/*
 * follow -- display the file, from an offset, forward.
 *
 */
void
follow(file_info_t *files, enum STYLE style, off_t off)
{
	int active, i, n = -1;
	struct stat sb2;
	file_info_t *file;
	struct timespec ts;

	/* Position each of the files */

	file = files;
	active = 0;
	n = 0;
	for (i = 0; i < no_files; i++, file++) {
		if (file->fp) {
			active = 1;
			n++;
			if (no_files > 1 && !qflag)
				(void)printf("\n==> %s <==\n", file->file_name);
			fname = file->file_name;
			forward(file->fp, style, off, &file->st);
			fname = NULL;
			if (Fflag && fileno(file->fp) != STDIN_FILENO)
			    n++;
		}
	}
	if (! active)
		return;

	last = --file;

	kq = kqueue();
	if (kq < 0)
		err(1, "kqueue");
	ev = malloc(n * sizeof(struct kevent));
	if (! ev)
	    err(1, "Couldn't allocate memory for kevents.");
	set_events(files);

	for (;;) {
		for (i = 0, file = files; i < no_files; i++, file++) {
			if (! file->fp)
				continue;
			if (Fflag && file->fp && fileno(file->fp) != STDIN_FILENO) {
				if (stat(file->file_name, &sb2) == 0 &&
				    (sb2.st_ino != file->st.st_ino ||
				     sb2.st_dev != file->st.st_dev ||
				     sb2.st_nlink == 0)) {
					show(file);
					file->fp = freopen(file->file_name, "r", file->fp);
					if (file->fp == NULL) {
						ierr();
						continue;
					} else {
						memcpy(&file->st, &sb2, sizeof(struct stat));
						set_events(files);
					}
				}
			}
			show(file);
		}

		switch (action) {
		case USE_KQUEUE:
			ts.tv_sec = 1;
			ts.tv_nsec = 0;
			/*
			 * In the -F case we set a timeout to ensure that
			 * we re-stat the file at least once every second.
			 */
			n = kevent(kq, NULL, 0, ev, 1, Fflag ? &ts : NULL);
			if (n < 0)
				err(1, "kevent");
			if (n == 0) {
				/* timeout */
				break;
			} else if (ev->filter == EVFILT_READ && ev->data < 0) {
				 /* file shrank, reposition to end */
				if (lseek(ev->ident, (off_t)0, SEEK_END) == -1) {
					ierr();
					continue;
				}
			}
			break;

		case USE_SLEEP:
			(void) usleep(250000);
			break;
		}
	}
}
