/* Test of fdatasync() function.
   Copyright (C) 2008-2017 Free Software Foundation, Inc.

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
SIGNATURE_CHECK (fdatasync, int, (int));

#include <errno.h>
#include <fcntl.h>

#include "macros.h"

int
main (void)
{
  int fd;
  const char *file = "test-fdatasync.txt";

  /* Assuming stdin and stdout are ttys, fdatasync is allowed to fail, but
     may succeed as an extension.  */
  for (fd = 0; fd < 2; fd++)
    if (fdatasync (fd) != 0)
      {
        ASSERT (errno == EINVAL /* POSIX */
                || errno == ENOTSUP /* seen on Mac OS X 10.5 */
                || errno == EBADF /* seen on AIX 7.1 */
                || errno == EIO /* seen on mingw */
                );
      }

  /* fdatasync must fail on invalid fd.  */
  {
    errno = 0;
    ASSERT (fdatasync (-1) == -1);
    ASSERT (errno == EBADF);
  }
  {
    close (99);
    errno = 0;
    ASSERT (fdatasync (99) == -1);
    ASSERT (errno == EBADF);
  }

  fd = open (file, O_WRONLY|O_CREAT|O_TRUNC, 0644);
  ASSERT (0 <= fd);
  ASSERT (write (fd, "hello", 5) == 5);
  ASSERT (fdatasync (fd) == 0);
  ASSERT (close (fd) == 0);

#if 0
  /* POSIX is self-contradictory on whether fdatasync must fail on
     read-only file descriptors.  Glibc allows it, as does our
     implementation if fsync allows it.  */
  fd = open (file, O_RDONLY);
  ASSERT (0 <= fd);
  errno = 0;
  ASSERT (fdatasync (fd) == -1);
  ASSERT (errno == EBADF);
  ASSERT (close (fd) == 0);
#endif

  ASSERT (unlink (file) == 0);

  return 0;
}
