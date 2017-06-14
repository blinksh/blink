/* Return a safer copy of a file descriptor.

   Copyright (C) 2005 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software Foundation,
   Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.  */

/* Written by Paul Eggert.  */

#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#include "unistd-safer.h"

#include <errno.h>

#include <unistd.h>
#ifndef STDIN_FILENO
# define STDIN_FILENO 0
#endif
#ifndef STDERR_FILENO
# define STDERR_FILENO 2
#endif

/* Return FD, unless FD would be a copy of standard input, output, or
   error; in that case, return a duplicate of FD, closing FD.  On
   failure to duplicate, close FD, set errno, and return -1.  Preserve
   errno if FD is negative, so that the caller can always inspect
   errno when the returned value is negative.

   This function is usefully wrapped around functions that return file
   descriptors, e.g., fd_safer (open ("file", O_RDONLY)).  */

int
fd_safer (int fd)
{
  if (STDIN_FILENO <= fd && fd <= STDERR_FILENO)
    {
      int f = dup_safer (fd);
      int e = errno;
      close (fd);
      errno = e;
      fd = f;
    }

  return fd;
}
