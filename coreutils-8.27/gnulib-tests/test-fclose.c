/* Test of fclose module.
   Copyright (C) 2011-2017 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, see <http://www.gnu.org/licenses/>.  */

/* Written by Eric Blake.  */

#include <config.h>

#include <stdio.h>

#include "signature.h"
SIGNATURE_CHECK (fclose, int, (FILE *));

#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "macros.h"

#define BASE "test-fclose.t"

int
main (int argc, char **argv)
{
  const char buf[] = "hello world";
  int fd;
  int fd2;
  FILE *f;

  /* Prepare a seekable file.  */
  fd = open (BASE, O_RDWR | O_CREAT | O_TRUNC, 0600);
  ASSERT (0 <= fd);
  ASSERT (write (fd, buf, sizeof buf) == sizeof buf);
  ASSERT (lseek (fd, 1, SEEK_SET) == 1);

  /* Create an output stream visiting the file; when it is closed, all
     other file descriptors visiting the file must see the new file
     position.  */
  fd2 = dup (fd);
  ASSERT (0 <= fd2);
  f = fdopen (fd2, "w");
  ASSERT (f);
  ASSERT (fputc (buf[1], f) == buf[1]);
  ASSERT (fclose (f) == 0);
  errno = 0;
  ASSERT (lseek (fd2, 0, SEEK_CUR) == -1);
  ASSERT (errno == EBADF);
  ASSERT (lseek (fd, 0, SEEK_CUR) == 2);

  /* Likewise for an input stream.  */
  fd2 = dup (fd);
  ASSERT (0 <= fd2);
  f = fdopen (fd2, "r");
  ASSERT (f);
  ASSERT (fgetc (f) == buf[2]);
  ASSERT (fclose (f) == 0);
  errno = 0;
  ASSERT (lseek (fd2, 0, SEEK_CUR) == -1);
  ASSERT (errno == EBADF);
  ASSERT (lseek (fd, 0, SEEK_CUR) == 3);

  /* Test that fclose() sets errno if someone else closes the stream
     fd behind the back of stdio.  */
  {
    FILE *fp = fdopen (fd, "w+");
    ASSERT (fp != NULL);
    ASSERT (close (fd) == 0);
    errno = 0;
    ASSERT (fclose (fp) == EOF);
    ASSERT (errno == EBADF);
  }

  /* Test that fclose() sets errno if the stream was constructed with
     an invalid file descriptor.  */
  {
    FILE *fp = fdopen (-1, "r");
    if (fp != NULL)
      {
        errno = 0;
        ASSERT (fclose (fp) == EOF);
        ASSERT (errno == EBADF);
      }
  }
  {
    FILE *fp;
    close (99);
    fp = fdopen (99, "r");
    if (fp != NULL)
      {
        errno = 0;
        ASSERT (fclose (fp) == EOF);
        ASSERT (errno == EBADF);
      }
  }

  /* Clean up.  */
  ASSERT (remove (BASE) == 0);

  return 0;
}
