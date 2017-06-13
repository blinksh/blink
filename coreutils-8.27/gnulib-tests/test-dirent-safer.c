/* Test that directory streams leave standard fds alone.
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

#include "dirent--.h"

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

#include "unistd-safer.h"

/* This test intentionally closes stderr.  So, we arrange to have fd 10
   (outside the range of interesting fd's during the test) set up to
   duplicate the original stderr.  */

#define BACKUP_STDERR_FILENO 10
#define ASSERT_STREAM myerr
#include "macros.h"

static FILE *myerr;

int
main (void)
{
  int i;
  DIR *dp;
  /* The dirent-safer module works without the use of fdopendir (which
     would also pull in fchdir and openat); but if those modules were
     also used, we ensure that they are safe.  In particular, the
     gnulib version of fdopendir is unable to guarantee that
     dirfd(fdopendir(fd))==fd, but we can at least guarantee that if
     they are not equal, the fd returned by dirfd is safe.  */
#if HAVE_FDOPENDIR || GNULIB_TEST_FDOPENDIR
  int dfd;
#endif

  /* We close fd 2 later, so save it in fd 10.  */
  if (dup2 (STDERR_FILENO, BACKUP_STDERR_FILENO) != BACKUP_STDERR_FILENO
      || (myerr = fdopen (BACKUP_STDERR_FILENO, "w")) == NULL)
    return 2;

#if HAVE_FDOPENDIR || GNULIB_TEST_FDOPENDIR
  dfd = open (".", O_RDONLY);
  ASSERT (STDERR_FILENO < dfd);
#endif

  /* Four iterations, with progressively more standard descriptors
     closed.  */
  for (i = -1; i <= STDERR_FILENO; i++)
    {
      if (0 <= i)
        ASSERT (close (i) == 0);
      dp = opendir (".");
      ASSERT (dp);
      ASSERT (dirfd (dp) == -1 || STDERR_FILENO < dirfd (dp));
      ASSERT (closedir (dp) == 0);

#if HAVE_FDOPENDIR || GNULIB_TEST_FDOPENDIR
      {
        int fd = dup_safer (dfd);
        ASSERT (STDERR_FILENO < fd);
        dp = fdopendir (fd);
        ASSERT (dp);
        ASSERT (dirfd (dp) == -1 || STDERR_FILENO < dirfd (dp));
        ASSERT (closedir (dp) == 0);
        errno = 0;
        ASSERT (close (fd) == -1);
        ASSERT (errno == EBADF);
      }
#endif
    }

#if HAVE_FDOPENDIR || GNULIB_TEST_FDOPENDIR
  ASSERT (close (dfd) == 0);
#endif

  return 0;
}
