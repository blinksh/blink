/* Tests of fdutimensat.
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

#include "utimens.h"

#include <fcntl.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include "ignore-value.h"
#include "macros.h"

#define BASE "test-fdutimensat.t"

#include "test-futimens.h"
#include "test-lutimens.h"
#include "test-utimens.h"

static int dfd = AT_FDCWD;

/* Wrap fdutimensat to behave like futimens.  */
static int
do_futimens (int fd, struct timespec const times[2])
{
  return fdutimensat (fd, dfd, NULL, times, 0);
}

/* Test the use of file descriptors alongside a name.  */
static int
do_fdutimens (char const *name, struct timespec const times[2])
{
  int result;
  int nofollow_result;
  int nofollow_errno;
  int fd = openat (dfd, name, O_WRONLY);
  if (fd < 0)
    fd = openat (dfd, name, O_RDONLY);
  errno = 0;
  nofollow_result = fdutimensat (fd, dfd, name, times, AT_SYMLINK_NOFOLLOW);
  nofollow_errno = errno;
  result = fdutimensat (fd, dfd, name, times, 0);
  ASSERT (result == nofollow_result
          || (nofollow_result == -1 && nofollow_errno == ENOSYS));
  if (0 <= fd)
    {
      int saved_errno = errno;
      close (fd);
      errno = saved_errno;
    }
  return result;
}

/* Wrap lutimensat to behave like lutimens.  */
static int
do_lutimens (const char *name, struct timespec const times[2])
{
  return lutimensat (dfd, name, times);
}

/* Wrap fdutimensat to behave like lutimens.  */
static int
do_lutimens1 (const char *name, struct timespec const times[2])
{
  return fdutimensat (-1, dfd, name, times, AT_SYMLINK_NOFOLLOW);
}

/* Wrap fdutimensat to behave like utimens.  */
static int
do_utimens (const char *name, struct timespec const times[2])
{
  return fdutimensat (-1, dfd, name, times, 0);
}

int
main (void)
{
  int result1; /* Skip because of no symlink support.  */
  int result2; /* Skip because of no futimens support.  */
  int result3; /* Skip because of no lutimens support.  */
  int fd;

  /* Clean up any trash from prior testsuite runs.  */
  ignore_value (system ("rm -rf " BASE "*"));

  /* Basic tests.  */
  result1 = test_utimens (do_utimens, true);
  ASSERT (test_utimens (do_fdutimens, false) == result1);
  result2 = test_futimens (do_futimens, result1 == 0);
  result3 = test_lutimens (do_lutimens, (result1 + result2) == 0);
  /* We expect 0/0, 0/77, or 77/77, but not 77/0.  */
  ASSERT (result1 <= result3);
  ASSERT (test_lutimens (do_lutimens1, (result1 + result2) == 0) == result3);
  dfd = open (".", O_RDONLY);
  ASSERT (0 <= dfd);
  ASSERT (test_utimens (do_utimens, false) == result1);
  ASSERT (test_utimens (do_fdutimens, false) == result1);
  ASSERT (test_futimens (do_futimens, false) == result2);
  ASSERT (test_lutimens (do_lutimens, false) == result3);
  ASSERT (test_lutimens (do_lutimens1, false) == result3);

  /* Directory relative tests.  */
  ASSERT (mkdir (BASE "dir", 0700) == 0);
  ASSERT (chdir (BASE "dir") == 0);
  fd = creat ("file", 0600);
  ASSERT (0 <= fd);
  errno = 0;
  ASSERT (fdutimensat (AT_FDCWD, fd, ".", NULL, 0) == -1);
  ASSERT (errno == ENOTDIR);
  {
    struct timespec ts[2] = { { Y2K, 0 }, { Y2K, 0 } };
    struct stat st;
    ASSERT (fdutimensat (fd, dfd, BASE "dir/file", ts, 0) == 0);
    ASSERT (stat ("file", &st) == 0);
    ASSERT (st.st_atime == Y2K);
    ASSERT (get_stat_atime_ns (&st) == 0);
    ASSERT (st.st_mtime == Y2K);
    ASSERT (get_stat_mtime_ns (&st) == 0);
  }
  ASSERT (close (fd) == 0);
  ASSERT (close (dfd) == 0);
  errno = 0;
  ASSERT (fdutimensat (-1, dfd, ".", NULL, 0) == -1);
  ASSERT (errno == EBADF);

  /* Cleanup.  */
  ASSERT (chdir ("..") == 0);
  ASSERT (unlink (BASE "dir/file") == 0);
  ASSERT (rmdir (BASE "dir") == 0);
  return result1 | result2 | result3;
}
