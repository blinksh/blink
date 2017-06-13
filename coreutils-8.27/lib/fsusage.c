/* fsusage.c -- return space usage of mounted file systems

   Copyright (C) 1991-1992, 1996, 1998-1999, 2002-2006, 2009-2017 Free Software
   Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

#include "config.h"

#include "fsusage.h"

#include <limits.h>
#include <sys/types.h>

#if STAT_STATVFS || STAT_STATVFS64 /* POSIX 1003.1-2001 (and later) with XSI */
# include <sys/statvfs.h>
#else
/* Don't include backward-compatibility files unless they're needed.
   Eventually we'd like to remove all this cruft.  */
# include <fcntl.h>
# include <unistd.h>
# include <sys/stat.h>
#if HAVE_SYS_PARAM_H
# include <sys/param.h>
#endif
#if HAVE_SYS_MOUNT_H
# include <sys/mount.h>
#endif
#if HAVE_SYS_VFS_H
# include <sys/vfs.h>
#endif
# if HAVE_SYS_FS_S5PARAM_H      /* Fujitsu UXP/V */
#  include <sys/fs/s5param.h>
# endif
# if defined HAVE_SYS_FILSYS_H && !defined _CRAY
#  include <sys/filsys.h>       /* SVR2 */
# endif
# if HAVE_SYS_STATFS_H
#  include <sys/statfs.h>
# endif
# if HAVE_DUSTAT_H              /* AIX PS/2 */
#  include <sys/dustat.h>
# endif
# include "full-read.h"
#endif

/* Many space usage primitives use all 1 bits to denote a value that is
   not applicable or unknown.  Propagate this information by returning
   a uintmax_t value that is all 1 bits if X is all 1 bits, even if X
   is unsigned and narrower than uintmax_t.  */
#define PROPAGATE_ALL_ONES(x) \
  ((sizeof (x) < sizeof (uintmax_t) \
    && (~ (x) == (sizeof (x) < sizeof (int) \
                  ? - (1 << (sizeof (x) * CHAR_BIT)) \
                  : 0))) \
   ? UINTMAX_MAX : (uintmax_t) (x))

/* Extract the top bit of X as an uintmax_t value.  */
#define EXTRACT_TOP_BIT(x) ((x) \
                            & ((uintmax_t) 1 << (sizeof (x) * CHAR_BIT - 1)))

/* If a value is negative, many space usage primitives store it into an
   integer variable by assignment, even if the variable's type is unsigned.
   So, if a space usage variable X's top bit is set, convert X to the
   uintmax_t value V such that (- (uintmax_t) V) is the negative of
   the original value.  If X's top bit is clear, just yield X.
   Use PROPAGATE_TOP_BIT if the original value might be negative;
   otherwise, use PROPAGATE_ALL_ONES.  */
#define PROPAGATE_TOP_BIT(x) ((x) | ~ (EXTRACT_TOP_BIT (x) - 1))

#ifdef STAT_STATVFS
/* Return true if statvfs works.  This is false for statvfs on systems
   with GNU libc on Linux kernels before 2.6.36, which stats all
   preceding entries in /proc/mounts; that makes df hang if even one
   of the corresponding file systems is hard-mounted but not available.  */
# if ! (__linux__ && (__GLIBC__ || __UCLIBC__))
/* The FRSIZE fallback is not required in this case.  */
#  undef STAT_STATFS2_FRSIZE
static int statvfs_works (void) { return 1; }
# else
#  include <string.h> /* for strverscmp */
#  include <sys/utsname.h>
#  include <sys/statfs.h>
#  define STAT_STATFS2_BSIZE 1

static int
statvfs_works (void)
{
  static int statvfs_works_cache = -1;
  struct utsname name;
  if (statvfs_works_cache < 0)
    statvfs_works_cache = (uname (&name) == 0
                           && 0 <= strverscmp (name.release, "2.6.36"));
  return statvfs_works_cache;
}
# endif
#endif


/* Fill in the fields of FSP with information about space usage for
   the file system on which FILE resides.
   DISK is the device on which FILE is mounted, for space-getting
   methods that need to know it.
   Return 0 if successful, -1 if not.  When returning -1, ensure that
   ERRNO is either a system error value, or zero if DISK is NULL
   on a system that requires a non-NULL value.  */
int
get_fs_usage (char const *file, char const *disk, struct fs_usage *fsp)
{
#ifdef STAT_STATVFS     /* POSIX, except pre-2.6.36 glibc/Linux */

  if (statvfs_works ())
    {
      struct statvfs vfsd;

      if (statvfs (file, &vfsd) < 0)
        return -1;

      /* f_frsize isn't guaranteed to be supported.  */
      fsp->fsu_blocksize = (vfsd.f_frsize
                            ? PROPAGATE_ALL_ONES (vfsd.f_frsize)
                            : PROPAGATE_ALL_ONES (vfsd.f_bsize));

      fsp->fsu_blocks = PROPAGATE_ALL_ONES (vfsd.f_blocks);
      fsp->fsu_bfree = PROPAGATE_ALL_ONES (vfsd.f_bfree);
      fsp->fsu_bavail = PROPAGATE_TOP_BIT (vfsd.f_bavail);
      fsp->fsu_bavail_top_bit_set = EXTRACT_TOP_BIT (vfsd.f_bavail) != 0;
      fsp->fsu_files = PROPAGATE_ALL_ONES (vfsd.f_files);
      fsp->fsu_ffree = PROPAGATE_ALL_ONES (vfsd.f_ffree);
      return 0;
    }

#endif

#if defined STAT_STATVFS64            /* AIX */

  struct statvfs64 fsd;

  if (statvfs64 (file, &fsd) < 0)
    return -1;

  /* f_frsize isn't guaranteed to be supported.  */
  fsp->fsu_blocksize = (fsd.f_frsize
                        ? PROPAGATE_ALL_ONES (fsd.f_frsize)
                        : PROPAGATE_ALL_ONES (fsd.f_bsize));

#elif defined STAT_STATFS2_FS_DATA      /* Ultrix */

  struct fs_data fsd;

  if (statfs (file, &fsd) != 1)
    return -1;

  fsp->fsu_blocksize = 1024;
  fsp->fsu_blocks = PROPAGATE_ALL_ONES (fsd.fd_req.btot);
  fsp->fsu_bfree = PROPAGATE_ALL_ONES (fsd.fd_req.bfree);
  fsp->fsu_bavail = PROPAGATE_TOP_BIT (fsd.fd_req.bfreen);
  fsp->fsu_bavail_top_bit_set = EXTRACT_TOP_BIT (fsd.fd_req.bfreen) != 0;
  fsp->fsu_files = PROPAGATE_ALL_ONES (fsd.fd_req.gtot);
  fsp->fsu_ffree = PROPAGATE_ALL_ONES (fsd.fd_req.gfree);

#elif defined STAT_READ_FILSYS          /* SVR2 */
# ifndef SUPERBOFF
#  define SUPERBOFF (SUPERB * 512)
# endif

  struct filsys fsd;
  int fd;

  if (! disk)
    {
      errno = 0;
      return -1;
    }

  fd = open (disk, O_RDONLY);
  if (fd < 0)
    return -1;
  lseek (fd, (off_t) SUPERBOFF, 0);
  if (full_read (fd, (char *) &fsd, sizeof fsd) != sizeof fsd)
    {
      close (fd);
      return -1;
    }
  close (fd);

  fsp->fsu_blocksize = (fsd.s_type == Fs2b ? 1024 : 512);
  fsp->fsu_blocks = PROPAGATE_ALL_ONES (fsd.s_fsize);
  fsp->fsu_bfree = PROPAGATE_ALL_ONES (fsd.s_tfree);
  fsp->fsu_bavail = PROPAGATE_TOP_BIT (fsd.s_tfree);
  fsp->fsu_bavail_top_bit_set = EXTRACT_TOP_BIT (fsd.s_tfree) != 0;
  fsp->fsu_files = (fsd.s_isize == -1
                    ? UINTMAX_MAX
                    : (fsd.s_isize - 2) * INOPB * (fsd.s_type == Fs2b ? 2 : 1));
  fsp->fsu_ffree = PROPAGATE_ALL_ONES (fsd.s_tinode);

#elif defined STAT_STATFS3_OSF1         /* OSF/1 */

  struct statfs fsd;

  if (statfs (file, &fsd, sizeof (struct statfs)) != 0)
    return -1;

  fsp->fsu_blocksize = PROPAGATE_ALL_ONES (fsd.f_fsize);

#elif defined STAT_STATFS2_FRSIZE        /* 2.6 < glibc/Linux < 2.6.36 */

  struct statfs fsd;

  if (statfs (file, &fsd) < 0)
    return -1;

  fsp->fsu_blocksize = PROPAGATE_ALL_ONES (fsd.f_frsize);

#elif defined STAT_STATFS2_BSIZE        /* glibc/Linux < 2.6, 4.3BSD, SunOS 4, \
                                           Mac OS X < 10.4, FreeBSD < 5.0, \
                                           NetBSD < 3.0, OpenBSD < 4.4 */

  struct statfs fsd;

  if (statfs (file, &fsd) < 0)
    return -1;

  fsp->fsu_blocksize = PROPAGATE_ALL_ONES (fsd.f_bsize);

# ifdef STATFS_TRUNCATES_BLOCK_COUNTS

  /* In SunOS 4.1.2, 4.1.3, and 4.1.3_U1, the block counts in the
     struct statfs are truncated to 2GB.  These conditions detect that
     truncation, presumably without botching the 4.1.1 case, in which
     the values are not truncated.  The correct counts are stored in
     undocumented spare fields.  */
  if (fsd.f_blocks == 0x7fffffff / fsd.f_bsize && fsd.f_spare[0] > 0)
    {
      fsd.f_blocks = fsd.f_spare[0];
      fsd.f_bfree = fsd.f_spare[1];
      fsd.f_bavail = fsd.f_spare[2];
    }
# endif /* STATFS_TRUNCATES_BLOCK_COUNTS */

#elif defined STAT_STATFS2_FSIZE        /* 4.4BSD and older NetBSD */

  struct statfs fsd;

  if (statfs (file, &fsd) < 0)
    return -1;

  fsp->fsu_blocksize = PROPAGATE_ALL_ONES (fsd.f_fsize);

#elif defined STAT_STATFS4              /* SVR3, Dynix, old Irix, old AIX, \
                                           Dolphin */

# if !_AIX && !defined _SEQUENT_ && !defined DOLPHIN
#  define f_bavail f_bfree
# endif

  struct statfs fsd;

  if (statfs (file, &fsd, sizeof fsd, 0) < 0)
    return -1;

  /* Empirically, the block counts on most SVR3 and SVR3-derived
     systems seem to always be in terms of 512-byte blocks,
     no matter what value f_bsize has.  */
# if _AIX || defined _CRAY
   fsp->fsu_blocksize = PROPAGATE_ALL_ONES (fsd.f_bsize);
# else
   fsp->fsu_blocksize = 512;
# endif

#endif

#if (defined STAT_STATVFS64 || defined STAT_STATFS3_OSF1                \
     || defined STAT_STATFS2_FRSIZE || defined STAT_STATFS2_BSIZE       \
     || defined STAT_STATFS2_FSIZE || defined STAT_STATFS4)

  fsp->fsu_blocks = PROPAGATE_ALL_ONES (fsd.f_blocks);
  fsp->fsu_bfree = PROPAGATE_ALL_ONES (fsd.f_bfree);
  fsp->fsu_bavail = PROPAGATE_TOP_BIT (fsd.f_bavail);
  fsp->fsu_bavail_top_bit_set = EXTRACT_TOP_BIT (fsd.f_bavail) != 0;
  fsp->fsu_files = PROPAGATE_ALL_ONES (fsd.f_files);
  fsp->fsu_ffree = PROPAGATE_ALL_ONES (fsd.f_ffree);

#endif

  (void) disk;  /* avoid argument-unused warning */
  return 0;
}

#if defined _AIX && defined _I386
/* AIX PS/2 does not supply statfs.  */

int
statfs (char *file, struct statfs *fsb)
{
  struct stat stats;
  struct dustat fsd;

  if (stat (file, &stats) != 0)
    return -1;
  if (dustat (stats.st_dev, 0, &fsd, sizeof (fsd)))
    return -1;
  fsb->f_type   = 0;
  fsb->f_bsize  = fsd.du_bsize;
  fsb->f_blocks = fsd.du_fsize - fsd.du_isize;
  fsb->f_bfree  = fsd.du_tfree;
  fsb->f_bavail = fsd.du_tfree;
  fsb->f_files  = (fsd.du_isize - 2) * fsd.du_inopb;
  fsb->f_ffree  = fsd.du_tinode;
  fsb->f_fsid.val[0] = fsd.du_site;
  fsb->f_fsid.val[1] = fsd.du_pckno;
  return 0;
}

#endif /* _AIX && _I386 */
