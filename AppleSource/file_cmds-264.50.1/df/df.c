/*
 * Copyright (c) 1980, 1990, 1993, 1994
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
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
"@(#) Copyright (c) 1980, 1990, 1993, 1994\n\
	The Regents of the University of California.  All rights reserved.\n";
#endif /* not lint */

#ifndef lint
#if 0
static char sccsid[] = "@(#)df.c	8.9 (Berkeley) 5/8/95";
#else
__used static const char rcsid[] =
  "$FreeBSD: src/bin/df/df.c,v 1.23.2.9 2002/07/01 00:14:24 iedowse Exp $";
#endif
#endif /* not lint */

#ifdef __APPLE__
#define MNT_IGNORE 0
#endif

#include <sys/cdefs.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <sys/mount.h>
#include <sys/sysctl.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <fstab.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sysexits.h>
#include <unistd.h>
#include <libutil.h>

#ifdef __APPLE__
#include "get_compat.h"
#else
#define COMPAT_MODE(func, mode) 1
#endif

#define UNITS_SI 1
#define UNITS_2 2

#define KILO_SZ(n) (n)
#define MEGA_SZ(n) ((n) * (n))
#define GIGA_SZ(n) ((n) * (n) * (n))
#define TERA_SZ(n) ((n) * (n) * (n) * (n))
#define PETA_SZ(n) ((n) * (n) * (n) * (n) * (n))

#define KILO_2_SZ (KILO_SZ(1024ULL))
#define MEGA_2_SZ (MEGA_SZ(1024ULL))
#define GIGA_2_SZ (GIGA_SZ(1024ULL))
#define TERA_2_SZ (TERA_SZ(1024ULL))
#define PETA_2_SZ (PETA_SZ(1024ULL))

#define KILO_SI_SZ (KILO_SZ(1000ULL))
#define MEGA_SI_SZ (MEGA_SZ(1000ULL))
#define GIGA_SI_SZ (GIGA_SZ(1000ULL))
#define TERA_SI_SZ (TERA_SZ(1000ULL))
#define PETA_SI_SZ (PETA_SZ(1000ULL))

/* Maximum widths of various fields. */
struct maxwidths {
	int mntfrom;
	int total;
	int used;
	int avail;
	int iused;
	int ifree;
};

unsigned long long vals_si [] = {1, KILO_SI_SZ, MEGA_SI_SZ, GIGA_SI_SZ, TERA_SI_SZ, PETA_SI_SZ};
unsigned long long vals_base2[] = {1, KILO_2_SZ, MEGA_2_SZ, GIGA_2_SZ, TERA_2_SZ, PETA_2_SZ};
unsigned long long *valp;

typedef enum { NONE, KILO, MEGA, GIGA, TERA, PETA, UNIT_MAX } unit_t;

unit_t unitp [] = { NONE, KILO, MEGA, GIGA, TERA, PETA };

int	  bread(off_t, void *, int);
int	  checkvfsname(const char *, char **);
char	 *getmntpt(char *);
int	  int64width(int64_t);
char	 *makenetvfslist(void);
char	**makevfslist(const char *);
void	  prthuman(struct statfs *, uint64_t);
void	  prthumanval(int64_t);
void	  prtstat(struct statfs *, struct maxwidths *);
long	  regetmntinfo(struct statfs **, long, char **);
unit_t	  unit_adjust(double *);
void	  update_maxwidths(struct maxwidths *, struct statfs *);
void	  usage(void);

int	aflag = 0, hflag, iflag, nflag;

static __inline int imax(int a, int b)
{
	return (a > b ? a : b);
}

int
main(int argc, char *argv[])
{
	struct stat stbuf;
	struct statfs statfsbuf, *mntbuf;
	struct maxwidths maxwidths;
	char *mntpt, **vfslist;
	long mntsize;
	int ch, i, rv, tflag = 0, kludge_tflag = 0;
	int kflag = 0;
	const char *options = "abgHhiklmnPt:T:";
	if (COMPAT_MODE("bin/df", "unix2003")) {
		/* Unix2003 requires -t be "include total capacity". which df
		  already does, but it conflicts with the old -t so we need to
		  *not* expect a string after -t (we provide -T in both cases
		  to cover the old use of -t) */
		options = "abgHhiklmnPtT:";
		iflag = 1;
	}

	vfslist = NULL;
	while ((ch = getopt(argc, argv, options)) != -1)
		switch (ch) {
		case 'a':
			aflag = 1;
			break;
		case 'b':
				/* FALLTHROUGH */
		case 'P':
			if (COMPAT_MODE("bin/df", "unix2003")) {
				if (!kflag) {
					/* -k overrides -P */
					putenv("BLOCKSIZE=512");
				}
				iflag = 0;
			} else {
				putenv("BLOCKSIZE=512");
			}
			hflag = 0;
			break;
		case 'g':
			putenv("BLOCKSIZE=1g");
			hflag = 0;
			break;
		case 'H':
			hflag = UNITS_SI;
			valp = vals_si;
			break;
		case 'h':
			hflag = UNITS_2;
			valp = vals_base2;
			break;
		case 'i':
			iflag = 1;
			break;
		case 'k':
			if (COMPAT_MODE("bin/df", "unix2003")) {
				putenv("BLOCKSIZE=1024");
			} else {
				putenv("BLOCKSIZE=1k");
			}
			kflag = 1;
			hflag = 0;
			break;
		case 'l':
			if (tflag)
				errx(1, "-l and -T are mutually exclusive.");
			if (vfslist != NULL)
				break;
			vfslist = makevfslist(makenetvfslist());
			break;
		case 'm':
			putenv("BLOCKSIZE=1m");
			hflag = 0;
			break;
		case 'n':
			nflag = 1;
			break;
		case 't':
			/* Unix2003 uses -t for something we do by default */
			if (COMPAT_MODE("bin/df", "unix2003")) {
			    kludge_tflag = 1;
			    break;
			}
		case 'T':
			if (vfslist != NULL) {
				if (tflag)
					errx(1, "only one -%c option may be specified", ch);
				else
					errx(1, "-l and -%c are mutually exclusive.", ch);
			}
			tflag++;
			vfslist = makevfslist(optarg);
			break;
		case '?':
		default:
			usage();
		}
	argc -= optind;
	argv += optind;

	/* If we are in unix2003 mode, have seen a -t but no -T and the first
	  non switch arg isn't a file, let's pretend they used -T on it.
	  This makes the Lexmark printer installer happy (PR-3918471) */
	if (tflag == 0 && kludge_tflag && *argv && stat(*argv, &stbuf) < 0
	  && errno == ENOENT) {
	    vfslist = makevfslist(*argv++);
	}

	mntsize = getmntinfo(&mntbuf, MNT_NOWAIT);
	bzero(&maxwidths, sizeof(maxwidths));
	for (i = 0; i < mntsize; i++)
		update_maxwidths(&maxwidths, &mntbuf[i]);

	rv = 0;
	if (!*argv) {
		mntsize = regetmntinfo(&mntbuf, mntsize, vfslist);
		bzero(&maxwidths, sizeof(maxwidths));
		for (i = 0; i < mntsize; i++)
			update_maxwidths(&maxwidths, &mntbuf[i]);
		for (i = 0; i < mntsize; i++) {
			if (aflag || (mntbuf[i].f_flags & MNT_IGNORE) == 0)
				prtstat(&mntbuf[i], &maxwidths);
		}
		exit(rv);
	}

	for (; *argv; argv++) {
		if (stat(*argv, &stbuf) < 0) {
			if ((mntpt = getmntpt(*argv)) == 0) {
				warn("%s", *argv);
				rv = 1;
				continue;
			}
		} else if (S_ISCHR(stbuf.st_mode) || S_ISBLK(stbuf.st_mode)) {
			warnx("%s: Raw devices not supported", *argv);
			rv = 1;
			continue;
		} else
			mntpt = *argv;
		/*
		 * Statfs does not take a `wait' flag, so we cannot
		 * implement nflag here.
		 */
		if (statfs(mntpt, &statfsbuf) < 0) {
			warn("%s", mntpt);
			rv = 1;
			continue;
		}
		/* Check to make sure the arguments we've been
		 * given are satisfied.  Return an error if we
		 * have been asked to list a mount point that does
		 * not match the other args we've been given (-l, -t, etc.)
		 */
		if (checkvfsname(statfsbuf.f_fstypename, vfslist)) {
			rv++;
			continue;
		}

		if (argc == 1) {
		        bzero(&maxwidths, sizeof(maxwidths));
			update_maxwidths(&maxwidths, &statfsbuf);
		}
		prtstat(&statfsbuf, &maxwidths);
	}
	return (rv);
}

char *
getmntpt(char *name)
{
	long mntsize, i;
	struct statfs *mntbuf;

	mntsize = getmntinfo(&mntbuf, MNT_NOWAIT);
	for (i = 0; i < mntsize; i++) {
		if (!strcmp(mntbuf[i].f_mntfromname, name))
			return (mntbuf[i].f_mntonname);
	}
	return (0);
}

/*
 * Make a pass over the filesystem info in ``mntbuf'' filtering out
 * filesystem types not in vfslist and possibly re-stating to get
 * current (not cached) info.  Returns the new count of valid statfs bufs.
 */
long
regetmntinfo(struct statfs **mntbufp, long mntsize, char **vfslist)
{
	int i, j;
	struct statfs *mntbuf;

	if (vfslist == NULL)
		return (nflag ? mntsize : getmntinfo(mntbufp, MNT_WAIT));

	mntbuf = *mntbufp;
	for (j = 0, i = 0; i < mntsize; i++) {
		if (checkvfsname(mntbuf[i].f_fstypename, vfslist))
			continue;
		if (!nflag)
			(void)statfs(mntbuf[i].f_mntonname,&mntbuf[j]);
		else if (i != j)
			mntbuf[j] = mntbuf[i];
		j++;
	}
	return (j);
}

/*
 * Output in "human-readable" format.  Uses 3 digits max and puts
 * unit suffixes at the end.  Makes output compact and easy to read,
 * especially on huge disks.
 *
 */
unit_t
unit_adjust(double *val)
{
	double abval;
	unit_t unit;
	unsigned int unit_sz;

	abval = fabs(*val);

	unit_sz = abval ? ilogb(abval) / 10 : 0;

	if (unit_sz >= UNIT_MAX) {
		unit = NONE;
	} else {
		unit = unitp[unit_sz];
		*val /= (double)valp[unit_sz];
	}

	return (unit);
}

void
prthuman(struct statfs *sfsp, uint64_t used)
{
	int64_t value;

	value = sfsp->f_blocks;
	value *= sfsp->f_bsize;
        prthumanval(value);
	value = used;
	value *= sfsp->f_bsize;
        prthumanval(value);
	value = sfsp->f_bavail;
	value *= sfsp->f_bsize;
	prthumanval(value);
}

void
prthumanval(int64_t bytes)
{
        char buf[6];
        int flags;

        flags = HN_B | HN_NOSPACE | HN_DECIMAL;
        if (hflag == UNITS_SI)
                flags |= HN_DIVISOR_1000;

        humanize_number(buf, sizeof(buf) - (bytes < 0 ? 0 : 1),
			bytes, "", HN_AUTOSCALE, flags);

	if (hflag == UNITS_SI)
		(void)printf(" %6s", buf);
	else
		(void)printf("%6si", buf);
	    
}

/*
 * Convert statfs returned filesystem size into BLOCKSIZE units.
 * Attempts to avoid overflow for large filesystems.
 */
static intmax_t fsbtoblk(int64_t num, uint64_t fsbs, u_long bs, char *fs) 
{
	if (num < 0) {
		warnx("negative filesystem block count/size from fs %s", fs);
		return 0;
	} else if ((fsbs != 0) && (fsbs < bs)) {
		return (num / (intmax_t) (bs / fsbs));
	} else {
		return (num * (intmax_t) (fsbs / bs));
	}
}

/*
 * Print out status about a filesystem.
 */
void
prtstat(struct statfs *sfsp, struct maxwidths *mwp)
{
	static long blocksize;
	static int headerlen, timesthrough;
	static const char *header;
	uint64_t used, availblks, inodes;
	char * avail_str;

	if (++timesthrough == 1) {
		mwp->mntfrom = imax(mwp->mntfrom, (int)strlen("Filesystem"));
		if (hflag) {
			header = "  Size";
			mwp->total = mwp->used = mwp->avail = (int)strlen(header);
		} else {
			header = getbsize(&headerlen, &blocksize);
			mwp->total = imax(mwp->total, headerlen);
		}
		mwp->used = imax(mwp->used, (int)strlen("Used"));
		if (COMPAT_MODE("bin/df", "unix2003") && !hflag) {
			avail_str = "Available";
		} else {
			avail_str = "Avail";
		}
		mwp->avail = imax(mwp->avail, (int)strlen(avail_str));

		(void)printf("%-*s %*s %*s %*s Capacity", mwp->mntfrom,
		    "Filesystem", mwp->total, header, mwp->used, "Used",
		    mwp->avail, avail_str);
		if (iflag) {
			mwp->iused = imax(mwp->iused, (int)strlen("  iused"));
			mwp->ifree = imax(mwp->ifree, (int)strlen("ifree"));
			(void)printf(" %*s %*s %%iused", mwp->iused - 2,
			    "iused", mwp->ifree, "ifree");
		}
		(void)printf("  Mounted on\n");
	}

	(void)printf("%-*s", mwp->mntfrom, sfsp->f_mntfromname);
	if (sfsp->f_blocks > sfsp->f_bfree)
		used = sfsp->f_blocks - sfsp->f_bfree;
	else
		used = 0;
	availblks = sfsp->f_bavail + used;
	if (hflag) {
		prthuman(sfsp, used);
	} else {
		(void)printf(" %*jd %*jd %*jd", mwp->total,
			     fsbtoblk(sfsp->f_blocks, sfsp->f_bsize, blocksize, sfsp->f_mntonname),
			     mwp->used, fsbtoblk(used, sfsp->f_bsize, blocksize, sfsp->f_mntonname),
			     mwp->avail, fsbtoblk(sfsp->f_bavail, sfsp->f_bsize, blocksize, sfsp->f_mntonname));
	}
	if (COMPAT_MODE("bin/df", "unix2003")) {
		/* Standard says percentage must be rounded UP to next
		   integer value, not truncated */
		double value;
		if (availblks == 0)
			value = 100.0;
		else {
			value = (double)used / (double)availblks * 100.0;
			if ((value-(int)value) > 0.0) value = value + 1.0;
		}
		(void)printf(" %5.0f%%", trunc(value));
	} else {
		(void)printf(" %5.0f%%",
		    availblks == 0 ? 100.0 : (double)used / (double)availblks * 100.0);
	}
	if (iflag) {
		inodes = sfsp->f_files;
		used = inodes - sfsp->f_ffree;
		(void)printf(" %*llu %*llu %4.0f%% ", mwp->iused, used,
		    mwp->ifree, sfsp->f_ffree, inodes == 0 ? 100.0 :
		    (double)used / (double)inodes * 100.0);
	} else
		(void)printf("  ");
	(void)printf("  %s\n", sfsp->f_mntonname);
}

/*
 * Update the maximum field-width information in `mwp' based on
 * the filesystem specified by `sfsp'.
 */
void
update_maxwidths(struct maxwidths *mwp, struct statfs *sfsp)
{
	static long blocksize;
	int dummy;

	if (blocksize == 0)
		getbsize(&dummy, &blocksize);

	mwp->mntfrom = imax(mwp->mntfrom, (int)strlen(sfsp->f_mntfromname));
	mwp->total = imax(mwp->total, int64width(fsbtoblk(sfsp->f_blocks,
							 sfsp->f_bsize, blocksize, sfsp->f_mntonname)));
	if (sfsp->f_blocks >= sfsp->f_bfree)
		mwp->used = imax(mwp->used, int64width(fsbtoblk(sfsp->f_blocks -
							       sfsp->f_bfree, sfsp->f_bsize, blocksize, sfsp->f_mntonname)));
	mwp->avail = imax(mwp->avail, int64width(fsbtoblk(sfsp->f_bavail,
							 sfsp->f_bsize, blocksize, sfsp->f_mntonname)));
	mwp->iused = imax(mwp->iused, int64width(sfsp->f_files - sfsp->f_ffree));
	mwp->ifree = imax(mwp->ifree, int64width(sfsp->f_ffree));
}

/* Return the width in characters of the specified long. */
int
int64width(int64_t val)
{
	int len;

	len = 0;
	/* Negative or zero values require one extra digit. */
	if (val <= 0) {
		val = -val;
		len++;
	}
	while (val > 0) {
		len++;
		val /= 10;
	}

	return (len);
}

void
usage(void)
{

	char *t_flag = COMPAT_MODE("bin/df", "unix2003") ? "[-t]" : "[-t type]";
	(void)fprintf(stderr,
	    "usage: df [-b | -H | -h | -k | -m | -g | -P] [-ailn] [-T type] %s [filesystem ...]\n", t_flag);
	exit(EX_USAGE);
}

char *
makenetvfslist(void)
{
	char *str, *strptr, **listptr;
#ifndef __APPLE__
	int mib[3], maxvfsconf, cnt=0, i;
	size_t miblen;
	struct ovfsconf *ptr;
#else
	int mib[4], maxvfsconf, cnt=0, i;
	size_t miblen;
	struct vfsconf vfc;
#endif

	mib[0] = CTL_VFS; mib[1] = VFS_GENERIC; mib[2] = VFS_MAXTYPENUM;
	miblen=sizeof(maxvfsconf);
	if (sysctl(mib, 3,
	    &maxvfsconf, &miblen, NULL, 0)) {
		warn("sysctl failed");
		return (NULL);
	}

	if ((listptr = malloc(sizeof(char*) * maxvfsconf)) == NULL) {
		warnx("malloc failed");
		return (NULL);
	}

#ifndef __APPLE__
	for (ptr = getvfsent(); ptr; ptr = getvfsent())
		if (ptr->vfc_flags & VFCF_NETWORK) {
			listptr[cnt++] = strdup(ptr->vfc_name);
			if (listptr[cnt-1] == NULL) {
				warnx("malloc failed");
				return (NULL);
			}
		}
#else
	miblen = sizeof (struct vfsconf);
	mib[2] = VFS_CONF;
        for (i = 0; i < maxvfsconf; i++) {
		mib[3] = i;
		if (sysctl(mib, 4, &vfc, &miblen, NULL, 0) == 0) {
	                if (!(vfc.vfc_flags & MNT_LOCAL)) {
	                        listptr[cnt++] = strdup(vfc.vfc_name);
	                        if (listptr[cnt-1] == NULL) {
					free(listptr);
	                                warnx("malloc failed");
	                                return (NULL);
	                        }
	                }
		}
	}
#endif

	if (cnt == 0 ||
	    (str = malloc(sizeof(char) * (32 * cnt + cnt + 2))) == NULL) {
		if (cnt > 0)
			warnx("malloc failed");
		free(listptr);
		return (NULL);
	}

	*str = 'n'; *(str + 1) = 'o';
	for (i = 0, strptr = str + 2; i < cnt; i++, strptr++) {
		strncpy(strptr, listptr[i], 32);
		strptr += strlen(listptr[i]);
		*strptr = ',';
		free(listptr[i]);
	}
	*(--strptr) = '\0';

	free(listptr);
	return (str);
}
