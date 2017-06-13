/* Tests of fchownat.
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

#include <unistd.h>

#include "signature.h"
SIGNATURE_CHECK (fchownat, int, (int, char const *, uid_t, gid_t, int));

#include <fcntl.h>
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>

#include "mgetgroups.h"
#include "openat.h"
#include "stat-time.h"
#include "ignore-value.h"
#include "macros.h"

#define BASE "test-fchownat.t"

#include "test-chown.h"
#include "test-lchown.h"

static int dfd = AT_FDCWD;

/* Wrapper around fchownat to test chown behavior.  */
static int
do_chown (char const *name, uid_t user, gid_t group)
{
  return chownat (dfd, name, user, group);
}

/* Wrapper around fchownat to test lchown behavior.  */
static int
do_lchown (char const *name, uid_t user, gid_t group)
{
  return lchownat (dfd, name, user, group);
}

int
main (int argc _GL_UNUSED, char *argv[])
{
  int result1; /* Skip because of no chown/symlink support.  */
  int result2; /* Skip because of no lchown support.  */

  /* Clean up any trash from prior testsuite runs.  */
  ignore_value (system ("rm -rf " BASE "*"));

  /* Test behaviour for invalid file descriptors.  */
  {
    errno = 0;
    ASSERT (fchownat (-1, "foo", getuid (), getgid (), 0) == -1);
    ASSERT (errno == EBADF);
  }
  {
    close (99);
    errno = 0;
    ASSERT (fchownat (99, "foo", getuid (), getgid (), 0) == -1);
    ASSERT (errno == EBADF);
  }

  /* Basic tests.  */
  result1 = test_chown (do_chown, true);
  result2 = test_lchown (do_lchown, result1 == 0);
  dfd = open (".", O_RDONLY);
  ASSERT (0 <= dfd);
  ASSERT (test_chown (do_chown, false) == result1);
  ASSERT (test_lchown (do_lchown, false) == result2);
  /* We expect 0/0, 0/77, or 77/77, but not 77/0.  */
  ASSERT (result1 <= result2);
  ASSERT (close (dfd) == 0);

  /* FIXME - add additional tests of dfd not at current directory.  */
  return result1 | result2;
}
