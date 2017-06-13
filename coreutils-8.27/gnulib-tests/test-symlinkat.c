/* Tests of symlinkat.
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
SIGNATURE_CHECK (symlinkat, int, (char const *, int, char const *));

#include <fcntl.h>
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#include "ignore-value.h"
#include "macros.h"

#ifndef HAVE_SYMLINK
# define HAVE_SYMLINK 0
#endif

#define BASE "test-symlinkat.t"

#include "test-symlink.h"

static int dfd = AT_FDCWD;

static int
do_symlink (char const *contents, char const *name)
{
  return symlinkat (contents, dfd, name);
}

int
main (void)
{
  int result;

  /* Remove any leftovers from a previous partial run.  */
  ignore_value (system ("rm -rf " BASE "*"));

  /* Test behaviour for invalid file descriptors.  */
  {
    errno = 0;
    ASSERT (symlinkat ("foo", -1, "bar") == -1);
    ASSERT (errno == EBADF
            || errno == ENOSYS /* seen on mingw */
           );
  }
  {
    close (99);
    errno = 0;
    ASSERT (symlinkat ("foo", 99, "bar") == -1);
    ASSERT (errno == EBADF
            || errno == ENOSYS /* seen on mingw */
           );
  }

  /* Perform same checks as counterpart functions.  */
  result = test_symlink (do_symlink, false);
  dfd = openat (AT_FDCWD, ".", O_RDONLY);
  ASSERT (0 <= dfd);
  ASSERT (test_symlink (do_symlink, false) == result);

  ASSERT (close (dfd) == 0);
  if (result == 77)
    fputs ("skipping test: symlinks not supported on this file system\n",
           stderr);
  return result;
}
