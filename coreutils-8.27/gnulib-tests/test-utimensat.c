/* Tests of utimensat.
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

/* Written by Eric Blake <ebb9@byu.net>, 2009.  */

#include <config.h>

#include <sys/stat.h>

#include "signature.h"
SIGNATURE_CHECK (utimensat, int, (int, char const *, struct timespec const[2],
                                  int));

#include <fcntl.h>
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "stat-time.h"
#include "timespec.h"
#include "utimecmp.h"
#include "ignore-value.h"
#include "macros.h"

#define BASE "test-utimensat.t"

#include "test-lutimens.h"
#include "test-utimens.h"

static int dfd = AT_FDCWD;

/* Wrap utimensat to behave like utimens.  */
static int
do_utimensat (char const *name, struct timespec const times[2])
{
  return utimensat (dfd, name, times, 0);
}

/* Wrap utimensat to behave like lutimens.  */
static int
do_lutimensat (char const *name, struct timespec const times[2])
{
  return utimensat (dfd, name, times, AT_SYMLINK_NOFOLLOW);
}

int
main (void)
{
  int result1; /* Skip because of no symlink support.  */
  int result2; /* Skip because of no lutimens support.  */
  int fd;

  /* Clean up any trash from prior testsuite runs.  */
  ignore_value (system ("rm -rf " BASE "*"));

  /* Test behaviour for invalid file descriptors.  */
  {
    errno = 0;
    ASSERT (utimensat (-1, "foo", NULL, 0) == -1);
    ASSERT (errno == EBADF);
  }
  {
    close (99);
    errno = 0;
    ASSERT (utimensat (99, "foo", NULL, 0) == -1);
    ASSERT (errno == EBADF);
  }

  /* Basic tests.  */
  result1 = test_utimens (do_utimensat, true);
  result2 = test_lutimens (do_lutimensat, result1 == 0);
  dfd = open (".", O_RDONLY);
  ASSERT (0 <= dfd);
  ASSERT (test_utimens (do_utimensat, false) == result1);
  ASSERT (test_lutimens (do_lutimensat, false) == result2);
  /* We expect 0/0, 0/77, or 77/77, but not 77/0.  */
  ASSERT (result1 <= result2);

  /* Directory-relative tests.  */
  ASSERT (mkdir (BASE "dir", 0700) == 0);
  ASSERT (chdir (BASE "dir") == 0);
  fd = creat ("file", 0600);
  ASSERT (0 <= fd);
  errno = 0;
  ASSERT (utimensat (fd, ".", NULL, 0) == -1);
  ASSERT (errno == ENOTDIR);
  {
    struct timespec ts[2] = { { Y2K, 0 }, { Y2K, 0 } };
    struct stat st;
    ASSERT (utimensat (dfd, BASE "dir/file", ts, AT_SYMLINK_NOFOLLOW) == 0);
    ASSERT (stat ("file", &st) == 0);
    ASSERT (st.st_atime == Y2K);
    ASSERT (get_stat_atime_ns (&st) == 0);
    ASSERT (st.st_mtime == Y2K);
    ASSERT (get_stat_mtime_ns (&st) == 0);
  }
  ASSERT (close (fd) == 0);
  ASSERT (close (dfd) == 0);
  errno = 0;
  ASSERT (utimensat (dfd, ".", NULL, 0) == -1);
  ASSERT (errno == EBADF);

  /* Cleanup.  */
  ASSERT (chdir ("..") == 0);
  ASSERT (unlink (BASE "dir/file") == 0);
  ASSERT (rmdir (BASE "dir") == 0);
  return result1 | result2;
}
