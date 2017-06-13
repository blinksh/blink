/* Tests of readlinkat.
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
SIGNATURE_CHECK (readlinkat, ssize_t, (int, char const *, char *, size_t));

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

#define BASE "test-readlinkat.t"

#include "test-readlink.h"

static int dfd = AT_FDCWD;

static ssize_t
do_readlink (char const *name, char *buf, size_t len)
{
  return readlinkat (dfd, name, buf, len);
}

int
main (void)
{
  char buf[80];
  int result;

  /* Remove any leftovers from a previous partial run.  */
  ignore_value (system ("rm -rf " BASE "*"));

  /* Test behaviour for invalid file descriptors.  */
  {
    errno = 0;
    ASSERT (readlinkat (-1, "foo", buf, sizeof buf) == -1);
    ASSERT (errno == EBADF);
  }
  {
    close (99);
    errno = 0;
    ASSERT (readlinkat (99, "foo", buf, sizeof buf) == -1);
    ASSERT (errno == EBADF);
  }

  /* Perform same checks as counterpart functions.  */
  result = test_readlink (do_readlink, false);
  dfd = openat (AT_FDCWD, ".", O_RDONLY);
  ASSERT (0 <= dfd);
  ASSERT (test_readlink (do_readlink, false) == result);

  /* Now perform some cross-directory checks.  Skip everything else on
     mingw.  */
  if (HAVE_SYMLINK)
    {
      const char *contents = "don't matter!";
      ssize_t exp = strlen (contents);

      /* Create link while cwd is '.', then read it in '..'.  */
      ASSERT (symlinkat (contents, AT_FDCWD, BASE "link") == 0);
      errno = 0;
      ASSERT (symlinkat (contents, dfd, BASE "link") == -1);
      ASSERT (errno == EEXIST);
      ASSERT (chdir ("..") == 0);
      errno = 0;
      ASSERT (readlinkat (AT_FDCWD, BASE "link", buf, sizeof buf) == -1);
      ASSERT (errno == ENOENT);
      ASSERT (readlinkat (dfd, BASE "link", buf, sizeof buf) == exp);
      ASSERT (strncmp (contents, buf, exp) == 0);
      ASSERT (unlinkat (dfd, BASE "link", 0) == 0);

      /* Create link while cwd is '..', then read it in '.'.  */
      ASSERT (symlinkat (contents, dfd, BASE "link") == 0);
      ASSERT (fchdir (dfd) == 0);
      errno = 0;
      ASSERT (symlinkat (contents, AT_FDCWD, BASE "link") == -1);
      ASSERT (errno == EEXIST);
      buf[0] = '\0';
      ASSERT (readlinkat (AT_FDCWD, BASE "link", buf, sizeof buf) == exp);
      ASSERT (strncmp (contents, buf, exp) == 0);
      buf[0] = '\0';
      ASSERT (readlinkat (dfd, BASE "link", buf, sizeof buf) == exp);
      ASSERT (strncmp (contents, buf, exp) == 0);
      ASSERT (unlink (BASE "link") == 0);
    }

  ASSERT (close (dfd) == 0);
  if (result == 77)
    fputs ("skipping test: symlinks not supported on this file system\n",
           stderr);
  return result;
}
