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

/* This file is designed to test both utimens(a,b) and
   utimensat(AT_FDCWD,a,b,0).  FUNC is the function to test.  Assumes
   that BASE and ASSERT are already defined.  If PRINT, warn before
   skipping tests with status 77.  */
static int
test_utimens (int (*func) (char const *, struct timespec const *), bool print)
{
  struct stat st1;
  struct stat st2;

  ASSERT (close (creat (BASE "file", 0600)) == 0);
  /* If utimens truncates to less resolution than the file system
     supports, then time can appear to go backwards between now and a
     follow-up utimens with UTIME_NOW or a NULL timespec.  Use
     UTIMECMP_TRUNCATE_SOURCE to compensate, with st1 as the
     source.  */
  ASSERT (stat (BASE "file", &st1) == 0);
  nap ();
  ASSERT (func (BASE "file", NULL) == 0);
  ASSERT (stat (BASE "file", &st2) == 0);
  ASSERT (0 <= utimecmp (BASE "file", &st2, &st1, UTIMECMP_TRUNCATE_SOURCE));
  if (check_ctime)
    ASSERT (ctime_compare (&st1, &st2) < 0);
  {
    /* On some NFS systems, the 'now' timestamp of creat or a NULL
       timespec is determined by the server, but the 'now' timestamp
       determined by gettime() (as is done when using UTIME_NOW) is
       determined by the client; since the two machines are not
       necessarily on the same clock, this is another case where time
       can appear to go backwards.  The rest of this test cares about
       client time, so manually use gettime() to set both times.  */
    struct timespec ts[2];
    gettime (&ts[0]);
    ts[1] = ts[0];
    ASSERT (func (BASE "file", ts) == 0);
    ASSERT (stat (BASE "file", &st1) == 0);
    nap ();
  }

  /* Invalid arguments.  */
  errno = 0;
  ASSERT (func ("no_such", NULL) == -1);
  ASSERT (errno == ENOENT);
  errno = 0;
  ASSERT (func ("no_such/", NULL) == -1);
  ASSERT (errno == ENOENT || errno == ENOTDIR);
  errno = 0;
  ASSERT (func ("", NULL) == -1);
  ASSERT (errno == ENOENT);
  {
    struct timespec ts[2] = { { Y2K, UTIME_BOGUS_POS }, { Y2K, 0 } };
    errno = 0;
    ASSERT (func (BASE "file", ts) == -1);
    ASSERT (errno == EINVAL);
  }
  {
    struct timespec ts[2] = { { Y2K, 0 }, { Y2K, UTIME_BOGUS_NEG } };
    errno = 0;
    ASSERT (func (BASE "file", ts) == -1);
    ASSERT (errno == EINVAL);
  }
  {
    struct timespec ts[2] = { { Y2K, 0 }, { Y2K, 0 } };
    errno = 0;
    ASSERT (func (BASE "file/", ts) == -1);
    ASSERT (errno == ENOTDIR || errno == EINVAL);
  }
  ASSERT (stat (BASE "file", &st2) == 0);
  ASSERT (st1.st_atime == st2.st_atime);
  ASSERT (get_stat_atime_ns (&st1) == get_stat_atime_ns (&st2));
  ASSERT (utimecmp (BASE "file", &st1, &st2, 0) == 0);

  /* Set both times.  */
  {
    struct timespec ts[2] = { { Y2K, BILLION / 2 - 1 }, { Y2K, BILLION - 1 } };
    ASSERT (func (BASE "file", ts) == 0);
    ASSERT (stat (BASE "file", &st2) == 0);
    ASSERT (st2.st_atime == Y2K);
    ASSERT (0 <= get_stat_atime_ns (&st2));
    ASSERT (get_stat_atime_ns (&st2) < BILLION / 2);
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
    ASSERT (func (BASE "file", ts) == 0);
    ASSERT (stat (BASE "file", &st3) == 0);
    ASSERT (st3.st_atime == Y2K);
    ASSERT (0 <= get_stat_atime_ns (&st3));
    ASSERT (get_stat_atime_ns (&st3) < BILLION / 2);
    /* See comment above about this utimecmp call.  */
    ASSERT (0 <= utimecmp (BASE "file", &st3, &st1, UTIMECMP_TRUNCATE_SOURCE));
    if (check_ctime)
      ASSERT (ctime_compare (&st2, &st3) < 0);
    nap ();
    ts[0].tv_nsec = 0;
    ts[1].tv_nsec = UTIME_OMIT;
    ASSERT (func (BASE "file", ts) == 0);
    ASSERT (stat (BASE "file", &st2) == 0);
    ASSERT (st2.st_atime == BILLION);
    ASSERT (get_stat_atime_ns (&st2) == 0);
    ASSERT (st3.st_mtime == st2.st_mtime);
    ASSERT (get_stat_mtime_ns (&st3) == get_stat_mtime_ns (&st2));
    if (check_ctime)
      ASSERT (ctime_compare (&st3, &st2) < 0);
  }

  /* Make sure this dereferences symlinks.  */
  if (symlink (BASE "file", BASE "link"))
    {
      ASSERT (unlink (BASE "file") == 0);
      if (print)
        fputs ("skipping test: symlinks not supported on this file system\n",
               stderr);
      return 77;
    }
  ASSERT (lstat (BASE "link", &st1) == 0);
  ASSERT (st1.st_mtime != Y2K);
  errno = 0;
  ASSERT (func (BASE "link/", NULL) == -1);
  ASSERT (errno == ENOTDIR);
  {
    struct timespec ts[2] = { { Y2K, 0 }, { Y2K, 0 } };
    ASSERT (func (BASE "link", ts) == 0);
    ASSERT (lstat (BASE "link", &st2) == 0);
    /* Can't compare atimes, since lstat() changes symlink atime on cygwin.  */
    ASSERT (st1.st_mtime == st2.st_mtime);
    ASSERT (stat (BASE "link", &st2) == 0);
    ASSERT (st2.st_mtime == Y2K);
    ASSERT (get_stat_mtime_ns (&st2) == 0);
  }

  /* Cleanup.  */
  ASSERT (unlink (BASE "link") == 0);
  ASSERT (unlink (BASE "file") == 0);
  return 0;
}
