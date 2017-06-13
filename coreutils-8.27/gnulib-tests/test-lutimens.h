/* Test of file timestamp modification functions.
   Copyright (C) 2009-2017 Free Software Foundation, Inc.

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

#include "test-utimens-common.h"

/* This file is designed to test both lutimens(a,b) and
   utimensat(AT_FDCWD,a,b,AT_SYMLINK_NOFOLLOW).  FUNC is the function
   to test.  Assumes that BASE and ASSERT are already defined.  If
   PRINT, warn before skipping tests with status 77.  */
static int
test_lutimens (int (*func) (char const *, struct timespec const *), bool print)
{
  int result;
  int saved_errno;
  struct stat st1;
  struct stat st2;
  bool atime_supported = true;

  /* Non-symlinks should be handled just like utimens.  */
  errno = 0;
  ASSERT (func ("no_such", NULL) == -1);
  ASSERT (errno == ENOENT);
  errno = 0;
  ASSERT (func ("no_such/", NULL) == -1);
  ASSERT (errno == ENOENT || errno == ENOTDIR);
  errno = 0;
  ASSERT (func ("", NULL) == -1);
  ASSERT (errno == ENOENT);
  ASSERT (close (creat (BASE "file", 0600)) == 0);
  ASSERT (stat (BASE "file", &st1) == 0);
  ASSERT (st1.st_atime != Y2K);
  ASSERT (st1.st_mtime != Y2K);
  {
    struct timespec ts[2] = { { Y2K, 0 }, { Y2K, 0 } };
    errno = 0;
    ASSERT (func (BASE "file/", ts) == -1);
    ASSERT (errno == ENOTDIR);
    ASSERT (stat (BASE "file", &st2) == 0);
    ASSERT (st1.st_atime == st2.st_atime);
    ASSERT (st1.st_mtime == st2.st_mtime);
  }
  {
    struct timespec ts[2] = { { Y2K, 0 }, { Y2K, 0 } };
    nap ();
    ASSERT (func (BASE "file", ts) == 0);
  }
  ASSERT (stat (BASE "file", &st2) == 0);
  ASSERT (st2.st_atime == Y2K);
  ASSERT (st2.st_mtime == Y2K);
  if (check_ctime)
    ASSERT (ctime_compare (&st1, &st2) < 0);

  /* Play with symlink timestamps.  */
  if (symlink (BASE "file", BASE "link"))
    {
      ASSERT (unlink (BASE "file") == 0);
      if (print)
        fputs ("skipping test: symlinks not supported on this file system\n",
               stderr);
      return 77;
    }
  errno = 0;
  result = func (BASE "link", NULL);
  saved_errno = errno;
  /* Make sure we did not reference through link by accident.  */
  ASSERT (stat (BASE "file", &st1) == 0);
  ASSERT (st1.st_atime == Y2K);
  ASSERT (st1.st_mtime == Y2K);
  ASSERT (lstat (BASE "link", &st1) == 0);
  ASSERT (st1.st_atime != Y2K);
  ASSERT (st1.st_mtime != Y2K);
  ASSERT (unlink (BASE "file") == 0);
  if (result == -1 && saved_errno == ENOSYS)
    {
      ASSERT (unlink (BASE "link") == 0);
      if (print)
        fputs ("skipping test: "
               "setting symlink time not supported on this file system\n",
               stderr);
      return 77;
    }
  ASSERT (!result);
  ASSERT (lstat (BASE "link", &st1) == 0);
  /* On cygwin, lstat() changes atime of symlinks, so that lutimens
     can only effectively modify mtime.  */
  nap ();
  ASSERT (lstat (BASE "link", &st2) == 0);
  if (st1.st_atime != st2.st_atime
      || get_stat_atime_ns (&st1) != get_stat_atime_ns (&st2))
    atime_supported = false;
  ASSERT (st1.st_ctime == st2.st_ctime);
  ASSERT (get_stat_ctime_ns (&st1) == get_stat_ctime_ns (&st2));

  /* Invalid arguments.  */
  {
    struct timespec ts[2] = { { Y2K, UTIME_BOGUS_POS }, { Y2K, 0 } };
    errno = 0;
    ASSERT (func (BASE "link", ts) == -1);
    ASSERT (errno == EINVAL);
  }
  {
    struct timespec ts[2] = { { Y2K, 0 }, { Y2K, UTIME_BOGUS_NEG } };
    errno = 0;
    ASSERT (func (BASE "link", ts) == -1);
    ASSERT (errno == EINVAL);
  }
  ASSERT (lstat (BASE "link", &st2) == 0);
  if (atime_supported)
    {
      ASSERT (st1.st_atime == st2.st_atime);
      ASSERT (get_stat_atime_ns (&st1) == get_stat_atime_ns (&st2));
    }
  ASSERT (utimecmp (BASE "link", &st1, &st2, 0) == 0);

  /* Set both times.  */
  {
    struct timespec ts[2] = { { Y2K, BILLION / 2 - 1 }, { Y2K, BILLION - 1 } };
    nap ();
    ASSERT (func (BASE "link", ts) == 0);
    ASSERT (lstat (BASE "link", &st2) == 0);
    if (atime_supported)
      {
        ASSERT (st2.st_atime == Y2K);
        ASSERT (0 <= get_stat_atime_ns (&st2));
        ASSERT (get_stat_atime_ns (&st2) < BILLION / 2);
      }
    ASSERT (st2.st_mtime == Y2K);
    ASSERT (0 <= get_stat_mtime_ns (&st2));
    ASSERT (get_stat_mtime_ns (&st2) < BILLION);
    if (check_ctime)
      ASSERT (ctime_compare (&st1, &st2) < 0);
  }

  /* Play with UTIME_OMIT, UTIME_NOW.  */
  {
    struct stat st3;
    struct timespec ts[2] = { { BILLION, UTIME_OMIT }, { 0, UTIME_NOW } };
    nap ();
    ASSERT (func (BASE "link", ts) == 0);
    ASSERT (lstat (BASE "link", &st3) == 0);
    if (atime_supported)
      {
        ASSERT (st3.st_atime == Y2K);
        ASSERT (0 <= get_stat_atime_ns (&st3));
        ASSERT (get_stat_atime_ns (&st3) < BILLION / 2);
      }
    ASSERT (utimecmp (BASE "link", &st1, &st3, 0) <= 0);
    if (check_ctime)
      ASSERT (ctime_compare (&st2, &st3) < 0);
    nap ();
    ts[0].tv_nsec = 0;
    ts[1].tv_nsec = UTIME_OMIT;
    ASSERT (func (BASE "link", ts) == 0);
    ASSERT (lstat (BASE "link", &st2) == 0);
    if (atime_supported)
      {
        ASSERT (st2.st_atime == BILLION);
        ASSERT (get_stat_atime_ns (&st2) == 0);
      }
    ASSERT (st3.st_mtime == st2.st_mtime);
    ASSERT (get_stat_mtime_ns (&st3) == get_stat_mtime_ns (&st2));
    if (check_ctime)
      ASSERT (ctime_compare (&st3, &st2) < 0);
  }

  /* Symlink to directory.  */
  ASSERT (unlink (BASE "link") == 0);
  ASSERT (symlink (BASE "dir", BASE "link") == 0);
  ASSERT (mkdir (BASE "dir", 0700) == 0);
  {
    struct timespec ts[2] = { { Y2K, 0 }, { Y2K, 0 } };
    ASSERT (func (BASE "link/", ts) == 0);
  }
  /* On cygwin 1.5, stat() changes atime of directories, so only check
     mtime.  */
  ASSERT (stat (BASE "dir", &st1) == 0);
  ASSERT (st1.st_mtime == Y2K);
  ASSERT (lstat (BASE "link", &st1) == 0);
  ASSERT (st1.st_atime != Y2K);
  ASSERT (st1.st_mtime != Y2K);
  ASSERT (func (BASE "link", NULL) == 0);
  ASSERT (stat (BASE "dir", &st1) == 0);
  ASSERT (st1.st_mtime == Y2K);
  ASSERT (lstat (BASE "link", &st1) == 0);
  ASSERT (st1.st_atime != Y2K);
  ASSERT (st1.st_mtime != Y2K);

  /* Cleanup.  */
  ASSERT (rmdir (BASE "dir") == 0);
  ASSERT (unlink (BASE "link") == 0);
  return 0;
}
