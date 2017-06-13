/* Invoke open, but return either a desired file descriptor or -1.

   Copyright (C) 2005-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* Written by Paul Eggert.  */

#include "config.h"

#include "fd-reopen.h"

#include <errno.h>
#include <fcntl.h>
#include <unistd.h>

/* Open a file to a particular file descriptor.  This is like standard
   'open', except it always returns DESIRED_FD if successful.  */

int
fd_reopen (int desired_fd, char const *file, int flags, mode_t mode)
{
  int fd = open (file, flags, mode);

  if (fd == desired_fd || fd < 0)
    return fd;
  else
    {
      int fd2 = dup2 (fd, desired_fd);
      int saved_errno = errno;
      close (fd);
      errno = saved_errno;
      return fd2;
    }
}
