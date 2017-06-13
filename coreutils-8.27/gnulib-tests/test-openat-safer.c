/* Test that openat_safer leave standard fds alone.
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

#include "fcntl--.h"

#include <errno.h>
#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>

/* This test intentionally closes stderr.  So, we arrange to have fd 10
   (outside the range of interesting fd's during the test) set up to
   duplicate the original stderr.  */

#define BACKUP_STDERR_FILENO 10
#define ASSERT_STREAM myerr
#include "macros.h"

static FILE *myerr;

#define witness "test-openat-safer.txt"

int
main (void)
{
  int i;
  int j;
  int dfd;
  int fd;
  char buf[2];

  /* We close fd 2 later, so save it in fd 10.  */
  if (dup2 (STDERR_FILENO, BACKUP_STDERR_FILENO) != BACKUP_STDERR_FILENO
      || (myerr = fdopen (BACKUP_STDERR_FILENO, "w")) == NULL)
    return 2;

  /* Create handle for future use.  */
  dfd = openat (AT_FDCWD, ".", O_RDONLY);
  ASSERT (STDERR_FILENO < dfd);

  /* Create file for later checks.  */
  remove (witness);
  fd = openat (dfd, witness, O_WRONLY | O_CREAT | O_EXCL, 0600);
  ASSERT (STDERR_FILENO < fd);
  ASSERT (write (fd, "hi", 2) == 2);
  ASSERT (close (fd) == 0);

  /* Four iterations, with progressively more standard descriptors
     closed.  */
  for (i = -1; i <= STDERR_FILENO; i++)
    {
      ASSERT (fchdir (dfd) == 0);
      if (0 <= i)
        ASSERT (close (i) == 0);

      /* Execute once in ".", once in "..".  */
      for (j = 0; j <= 1; j++)
        {
          if (j)
            ASSERT (chdir ("..") == 0);

          /* Check for error detection.  */
          errno = 0;
          ASSERT (openat (AT_FDCWD, "", O_RDONLY) == -1);
          ASSERT (errno == ENOENT);
          errno = 0;
          ASSERT (openat (dfd, "", O_RDONLY) == -1);
          ASSERT (errno == ENOENT);
          errno = 0;
          ASSERT (openat (-1, ".", O_RDONLY) == -1);
          ASSERT (errno == EBADF);

          /* Check for trailing slash and /dev/null handling.  */
          errno = 0;
          ASSERT (openat (dfd, "nonexist.ent/", O_CREAT | O_RDONLY,
                          S_IRUSR | S_IWUSR) == -1);
          ASSERT (errno == ENOTDIR || errno == EISDIR || errno == ENOENT
                  || errno == EINVAL);
          errno = 0;
          ASSERT (openat (dfd, witness "/", O_RDONLY) == -1);
          ASSERT (errno == ENOTDIR || errno == EISDIR || errno == EINVAL);
          /* Using a bad directory is okay for absolute paths.  */
          fd = openat (-1, "/dev/null", O_WRONLY);
          ASSERT (STDERR_FILENO < fd);
          /* Using a non-directory is wrong for relative paths.  */
          errno = 0;
          ASSERT (openat (fd, ".", O_RDONLY) == -1);
          ASSERT (errno == EBADF || errno == ENOTDIR);
          ASSERT (close (fd) == 0);

          /* Check for our witness file.  */
          fd = openat (dfd, witness, O_RDONLY | O_NOFOLLOW);
          ASSERT (STDERR_FILENO < fd);
          ASSERT (read (fd, buf, 2) == 2);
          ASSERT (buf[0] == 'h' && buf[1] == 'i');
          ASSERT (close (fd) == 0);
        }
    }
  ASSERT (fchdir (dfd) == 0);
  ASSERT (unlink (witness) == 0);
  ASSERT (close (dfd) == 0);

  return 0;
}
