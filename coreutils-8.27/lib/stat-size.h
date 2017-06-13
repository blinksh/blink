/* macros useful in interpreting size-related values in struct stat.
   Copyright (C) 1989, 1991-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */
/*
   Macros defined by this file (s is an rvalue of type struct stat):

   DEV_BSIZE:       The device blocksize.  But use ST_NBLOCKSIZE instead.
   ST_BLKSIZE(s):   Preferred (in the sense of best performance) I/O blocksize
                    for the file, in bytes.
   ST_NBLOCKS(s):   Number of blocks in the file, including indirect blocks.
   ST_NBLOCKSIZE:   Size of blocks used when calculating ST_NBLOCKS.
 */
#ifndef STAT_SIZE_H
#define STAT_SIZE_H

/* sys/param.h may define DEV_BSIZE */
#if HAVE_SYS_PARAM_H
# include <sys/param.h>
#endif


/* Get or fake the disk device blocksize.
   Usually defined by sys/param.h (if at all).  */
#if !defined DEV_BSIZE && defined BSIZE
# define DEV_BSIZE BSIZE
#endif
#if !defined DEV_BSIZE && defined BBSIZE /* SGI sys/param.h */
# define DEV_BSIZE BBSIZE
#endif
#ifndef DEV_BSIZE
# define DEV_BSIZE 4096
#endif



/* Extract or fake data from a 'struct stat'.
   ST_BLKSIZE: Preferred I/O blocksize for the file, in bytes.
   ST_NBLOCKS: Number of blocks in the file, including indirect blocks.
   ST_NBLOCKSIZE: Size of blocks used when calculating ST_NBLOCKS.  */
#ifndef HAVE_STRUCT_STAT_ST_BLOCKS
# define ST_BLKSIZE(statbuf) DEV_BSIZE
  /* coreutils' fileblocks.c also uses BSIZE.  */
# if defined _POSIX_SOURCE || !defined BSIZE
#  define ST_NBLOCKS(statbuf) \
  ((statbuf).st_size / ST_NBLOCKSIZE + ((statbuf).st_size % ST_NBLOCKSIZE != 0))
# else
   /* This definition calls st_blocks, which is in the fileblocks module. */
#  define ST_NBLOCKS(statbuf) \
  (S_ISREG ((statbuf).st_mode) || S_ISDIR ((statbuf).st_mode) ? \
   st_blocks ((statbuf).st_size) : 0)
# endif
#else
/* Some systems, like Sequents, return st_blksize of 0 on pipes.
   Also, when running 'rsh hpux11-system cat any-file', cat would
   determine that the output stream had an st_blksize of 2147421096.
   Conversely st_blksize can be 2 GiB (or maybe even larger) with XFS
   on 64-bit hosts.  Somewhat arbitrarily, limit the "optimal" block
   size to SIZE_MAX / 8 + 1.  (Dividing SIZE_MAX by only 4 wouldn't
   suffice, since "cat" sometimes multiplies the result by 4.)  If
   anyone knows of a system for which this limit is too small, please
   report it as a bug in this code.  */
# define ST_BLKSIZE(statbuf) ((0 < (statbuf).st_blksize \
                               && (statbuf).st_blksize <= ((size_t)-1) / 8 + 1) \
                              ? (statbuf).st_blksize : DEV_BSIZE)
# if defined hpux || defined __hpux__ || defined __hpux
  /* HP-UX counts st_blocks in 1024-byte units.
     This loses when mixing HP-UX and BSD file systems with NFS.  */
#  define ST_NBLOCKSIZE 1024
# else /* !hpux */
#  if defined _AIX && defined _I386
    /* AIX PS/2 counts st_blocks in 4K units.  */
#   define ST_NBLOCKSIZE (4 * 1024)
#  else
#   if defined _CRAY
#    define ST_NBLOCKS(statbuf) \
  (S_ISREG ((statbuf).st_mode) || S_ISDIR ((statbuf).st_mode) \
   ? (statbuf).st_blocks * ST_BLKSIZE (statbuf) / ST_NBLOCKSIZE : 0)
#   endif
#  endif
# endif
#endif

#ifndef ST_NBLOCKS
# define ST_NBLOCKS(statbuf) ((statbuf).st_blocks)
#endif

#ifndef ST_NBLOCKSIZE
# ifdef S_BLKSIZE
#  define ST_NBLOCKSIZE S_BLKSIZE
# else
#  define ST_NBLOCKSIZE 512
# endif
#endif

#endif /* STAT_SIZE_H */
