/* Test isatty() function.
   Copyright (C) 2011-2017 Free Software Foundation, Inc.

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

#include <config.h>

#include <unistd.h>

#include "signature.h"
SIGNATURE_CHECK (isatty, int, (int));

#include <errno.h>
#include <fcntl.h>

#include "macros.h"

/* The name of the "always silent" device.  */
#if (defined _WIN32 || defined __WIN32__) && ! defined __CYGWIN__
/* Native Windows API.  */
# define DEV_NULL "NUL"
#else
/* Unix API.  */
# define DEV_NULL "/dev/null"
#endif

int
main (void)
{
  const char *file = "test-isatty.txt";

  /* Test behaviour for invalid file descriptors.  */
  {
    errno = 0;
    ASSERT (isatty (-1) == 0);
    ASSERT (errno == EBADF
            || errno == 0 /* seen on IRIX 6.5, Solaris 10 */
           );
  }
  {
    close (99);
    errno = 0;
    ASSERT (isatty (99) == 0);
    ASSERT (errno == EBADF
            || errno == 0 /* seen on IRIX 6.5, Solaris 10 */
           );
  }

  /* Test behaviour for regular files.  */
  {
    int fd;

    fd = open (file, O_WRONLY|O_CREAT|O_TRUNC, 0644);
    ASSERT (0 <= fd);
    ASSERT (write (fd, "hello", 5) == 5);
    ASSERT (close (fd) == 0);

    fd = open (file, O_RDONLY);
    ASSERT (0 <= fd);
    ASSERT (! isatty (fd));
    ASSERT (close (fd) == 0);
  }

  /* Test behaviour for pipes.  */
  {
    int fd[2];

    ASSERT (pipe (fd) == 0);
    ASSERT (! isatty (fd[0]));
    ASSERT (! isatty (fd[1]));
    ASSERT (close (fd[0]) == 0);
    ASSERT (close (fd[1]) == 0);
  }

  /* Test behaviour for /dev/null.  */
  {
    int fd;

    fd = open (DEV_NULL, O_RDONLY);
    ASSERT (0 <= fd);
    ASSERT (! isatty (fd));
    ASSERT (close (fd) == 0);
  }

  ASSERT (unlink (file) == 0);

  return 0;
}
