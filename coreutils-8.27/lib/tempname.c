/* tempname.c - generate the name of a temporary file.

   Copyright (C) 1991-2003, 2005-2007, 2009-2017 Free Software Foundation, Inc.

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

/* Extracted from glibc sysdeps/posix/tempname.c.  See also tmpdir.c.  */

#if !_LIBC
# include "config.h"
# include "tempname.h"
# include "randint.h"
#endif

#include <sys/types.h>
#include <assert.h>

#include <errno.h>
#ifndef __set_errno
# define __set_errno(Val) errno = (Val)
#endif

#include <stdio.h>
#ifndef P_tmpdir
# define P_tmpdir "/tmp"
#endif
#ifndef TMP_MAX
# define TMP_MAX 238328
#endif
#ifndef __GT_FILE
# define __GT_FILE      0
# define __GT_DIR       1
# define __GT_NOCREATE  2
#endif
#if !_LIBC && (GT_FILE != __GT_FILE || GT_DIR != __GT_DIR       \
               || GT_NOCREATE != __GT_NOCREATE)
# error report this to bug-gnulib@gnu.org
#endif

#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include <fcntl.h>
#include <sys/time.h>
#include <stdint.h>
#include <unistd.h>

#include <sys/stat.h>

#if _LIBC
# define struct_stat64 struct stat64
#else
# define struct_stat64 struct stat
# define __try_tempname try_tempname
# define __gen_tempname gen_tempname
# define __getpid getpid
# define __gettimeofday gettimeofday
# define __mkdir mkdir
# define __open open
# define __lxstat64(version, file, buf) lstat (file, buf)
# define __secure_getenv secure_getenv
#endif

#ifdef _LIBC
# include <hp-timing.h>
# if HP_TIMING_AVAIL
#  define RANDOM_BITS(Var) \
  if (__builtin_expect (value == UINT64_C (0), 0))                            \
    {                                                                         \
      /* If this is the first time this function is used initialize           \
         the variable we accumulate the value in to some somewhat             \
         random value.  If we'd not do this programs at startup time          \
         might have a reduced set of possible names, at least on slow         \
         machines.  */                                                        \
      struct timeval tv;                                                      \
      __gettimeofday (&tv, NULL);                                             \
      value = ((uint64_t) tv.tv_usec << 16) ^ tv.tv_sec;                      \
    }                                                                         \
  HP_TIMING_NOW (Var)
# endif
#endif

/* Use the widest available unsigned type if uint64_t is not
   available.  The algorithm below extracts a number less than 62**6
   (approximately 2**35.725) from uint64_t, so ancient hosts where
   uintmax_t is only 32 bits lose about 3.725 bits of randomness,
   which is better than not having mkstemp at all.  */
#if !defined UINT64_MAX && !defined uint64_t
# define uint64_t uintmax_t
#endif

#if _LIBC
/* Return nonzero if DIR is an existent directory.  */
static int
direxists (const char *dir)
{
  struct_stat64 buf;
  return __xstat64 (_STAT_VER, dir, &buf) == 0 && S_ISDIR (buf.st_mode);
}

/* Path search algorithm, for tmpnam, tmpfile, etc.  If DIR is
   non-null and exists, uses it; otherwise uses the first of $TMPDIR,
   P_tmpdir, /tmp that exists.  Copies into TMPL a template suitable
   for use with mk[s]temp.  Will fail (-1) if DIR is non-null and
   doesn't exist, none of the searched dirs exists, or there's not
   enough space in TMPL. */
int
__path_search (char *tmpl, size_t tmpl_len, const char *dir, const char *pfx,
               int try_tmpdir)
{
  const char *d;
  size_t dlen, plen;

  if (!pfx || !pfx[0])
    {
      pfx = "file";
      plen = 4;
    }
  else
    {
      plen = strlen (pfx);
      if (plen > 5)
        plen = 5;
    }

  if (try_tmpdir)
    {
      d = __secure_getenv ("TMPDIR");
      if (d != NULL && direxists (d))
        dir = d;
      else if (dir != NULL && direxists (dir))
        /* nothing */ ;
      else
        dir = NULL;
    }
  if (dir == NULL)
    {
      if (direxists (P_tmpdir))
        dir = P_tmpdir;
      else if (strcmp (P_tmpdir, "/tmp") != 0 && direxists ("/tmp"))
        dir = "/tmp";
      else
        {
          __set_errno (ENOENT);
          return -1;
        }
    }

  dlen = strlen (dir);
  while (dlen > 1 && dir[dlen - 1] == '/')
    dlen--;                     /* remove trailing slashes */

  /* check we have room for "${dir}/${pfx}XXXXXX\0" */
  if (tmpl_len < dlen + 1 + plen + 6 + 1)
    {
      __set_errno (EINVAL);
      return -1;
    }

  sprintf (tmpl, "%.*s/%.*sXXXXXX", (int) dlen, dir, (int) plen, pfx);
  return 0;
}
#endif /* _LIBC */

static inline bool _GL_ATTRIBUTE_PURE
check_x_suffix (char const *s, size_t len)
{
  return len <= strspn (s, "X");
}

/* These are the characters used in temporary file names.  */
static const char letters[] =
"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

int
try_tempname_len (char *tmpl, int suffixlen, void *args,
                  int (*tryfunc) (char *, void *), size_t x_suffix_len)
{
  size_t len;
  char *XXXXXX;
  unsigned int count;
  int fd = -1;
  int save_errno = errno;
  struct randint_source *rand_src;

  /* A lower bound on the number of temporary files to attempt to
     generate.  The maximum total number of temporary file names that
     can exist for a given template is 62**6.  It should never be
     necessary to try all of these combinations.  Instead if a reasonable
     number of names is tried (we define reasonable as 62**3) fail to
     give the system administrator the chance to remove the problems.
     This value requires that X_SUFFIX_LEN be at least 3.  */
#define ATTEMPTS_MIN (62 * 62 * 62)

  /* The number of times to attempt to generate a temporary file.  To
     conform to POSIX, this must be no smaller than TMP_MAX.  */
#if ATTEMPTS_MIN < TMP_MAX
  unsigned int attempts = TMP_MAX;
#else
  unsigned int attempts = ATTEMPTS_MIN;
#endif

  len = strlen (tmpl);
  if (len < x_suffix_len + suffixlen
      || ! check_x_suffix (&tmpl[len - x_suffix_len - suffixlen],
                           x_suffix_len))
    {
      __set_errno (EINVAL);
      return -1;
    }

  /* This is where the Xs start.  */
  XXXXXX = &tmpl[len - x_suffix_len - suffixlen];

  /* Get some more or less random data.  */
  rand_src = randint_all_new (NULL, x_suffix_len);
  if (! rand_src)
    return -1;

  for (count = 0; count < attempts; ++count)
    {
      size_t i;

      for (i = 0; i < x_suffix_len; i++)
        XXXXXX[i] = letters[randint_genmax (rand_src, sizeof letters - 2)];

      fd = tryfunc (tmpl, args);
      if (fd >= 0)
        {
          __set_errno (save_errno);
          goto done;
        }
      else if (errno != EEXIST)
        {
          fd = -1;
          goto done;
        }
    }

  randint_all_free (rand_src);

  /* We got out of the loop because we ran out of combinations to try.  */
  __set_errno (EEXIST);
  return -1;

 done:
  {
    int saved_errno = errno;
    randint_all_free (rand_src);
    __set_errno (saved_errno);
  }
  return fd;
}

static int
try_file (char *tmpl, void *flags)
{
  int *openflags = flags;
  return __open (tmpl,
                 (*openflags & ~O_ACCMODE)
                 | O_RDWR | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR);
}

static int
try_dir (char *tmpl, void *flags _GL_UNUSED)
{
  return __mkdir (tmpl, S_IRUSR | S_IWUSR | S_IXUSR);
}

static int
try_nocreate (char *tmpl, void *flags _GL_UNUSED)
{
  struct_stat64 st;

  if (__lxstat64 (_STAT_VER, tmpl, &st) == 0)
    __set_errno (EEXIST);
  return errno == ENOENT ? 0 : -1;
}

/* Generate a temporary file name based on TMPL.  TMPL must match the
   rules for mk[s]temp (i.e., end in at least X_SUFFIX_LEN "X"s,
   possibly with a suffix).
   The name constructed does not exist at the time of the call to
   this function.  TMPL is overwritten with the result.

   KIND may be one of:
   __GT_NOCREATE:       simply verify that the name does not exist
                        at the time of the call.
   __GT_FILE:           create the file using open(O_CREAT|O_EXCL)
                        and return a read-write fd.  The file is mode 0600.
   __GT_DIR:            create a directory, which will be mode 0700.

   We use a clever algorithm to get hard-to-predict names. */
int
gen_tempname_len (char *tmpl, int suffixlen, int flags, int kind,
                  size_t x_suffix_len)
{
  int (*tryfunc) (char *, void *);

  switch (kind)
    {
    case __GT_FILE:
      tryfunc = try_file;
      break;

    case __GT_DIR:
      tryfunc = try_dir;
      break;

    case __GT_NOCREATE:
      tryfunc = try_nocreate;
      break;

    default:
      assert (! "invalid KIND in __gen_tempname");
      abort ();
    }
  return try_tempname_len (tmpl, suffixlen, &flags, tryfunc, x_suffix_len);
}

int
__gen_tempname (char *tmpl, int suffixlen, int flags, int kind)
{
  return gen_tempname_len (tmpl, suffixlen, flags, kind, 6);
}

int
__try_tempname (char *tmpl, int suffixlen, void *args,
                int (*tryfunc) (char *, void *))
{
  return try_tempname_len (tmpl, suffixlen, args, tryfunc, 6);
}
