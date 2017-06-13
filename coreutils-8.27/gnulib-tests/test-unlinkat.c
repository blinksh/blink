/* Tests of unlinkat.
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
SIGNATURE_CHECK (unlinkat, int, (int, char const *, int));

#include <fcntl.h>
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>

#include "unlinkdir.h"
#include "ignore-value.h"
#include "macros.h"

#define BASE "test-unlinkat.t"

#include "test-rmdir.h"
#include "test-unlink.h"

static int dfd = AT_FDCWD;

/* Wrapper around unlinkat to test rmdir behavior.  */
static int
rmdirat (char const *name)
{
  return unlinkat (dfd, name, AT_REMOVEDIR);
}

/* Wrapper around unlinkat to test unlink behavior.  */
static int
unlinker (char const *name)
{
  return unlinkat (dfd, name, 0);
}

int
main (int argc _GL_UNUSED, char *argv[])
{
  /* FIXME: Add tests of fd other than ".".  */
  int result1;
  int result2;

  /* Remove any leftovers from a previous partial run.  */
  ignore_value (system ("rm -rf " BASE "*"));

  /* Test behaviour for invalid file descriptors.  */
  {
    errno = 0;
    ASSERT (unlinkat (-1, "foo", 0) == -1);
    ASSERT (errno == EBADF);
  }
  {
    close (99);
    errno = 0;
    ASSERT (unlinkat (99, "foo", 0) == -1);
    ASSERT (errno == EBADF);
  }

  result1 = test_rmdir_func (rmdirat, false);
  result2 = test_unlink_func (unlinker, false);
  ASSERT (result1 == result2);
  dfd = open (".", O_RDONLY);
  ASSERT (0 <= dfd);
  result2 = test_rmdir_func (rmdirat, false);
  ASSERT (result1 == result2);
  result2 = test_unlink_func (unlinker, false);
  ASSERT (result1 == result2);
  ASSERT (close (dfd) == 0);
  if (result1 == 77)
    fputs ("skipping test: symlinks not supported on this file system\n",
           stderr);
  return result1;
}
