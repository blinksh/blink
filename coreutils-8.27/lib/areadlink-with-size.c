/* readlink wrapper to return the link name in malloc'd storage.
   Unlike xreadlink and xreadlink_with_size, don't ever call exit.

   Copyright (C) 2001, 2003-2007, 2009-2017 Free Software Foundation, Inc.

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

/* Written by Jim Meyering <jim@meyering.net>  */

#include "config.h"

#include "areadlink.h"

#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>

#ifndef SSIZE_MAX
# define SSIZE_MAX ((ssize_t) (SIZE_MAX / 2))
#endif

/* SYMLINK_MAX is used only for an initial memory-allocation sanity
   check, so it's OK to guess too small on hosts where there is no
   arbitrary limit to symbolic link length.  */
#ifndef SYMLINK_MAX
# define SYMLINK_MAX 1024
#endif

#define MAXSIZE (SIZE_MAX < SSIZE_MAX ? SIZE_MAX : SSIZE_MAX)

/* Call readlink to get the symbolic link value of FILE.
   SIZE is a hint as to how long the link is expected to be;
   typically it is taken from st_size.  It need not be correct.
   Return a pointer to that NUL-terminated string in malloc'd storage.
   If readlink fails, malloc fails, or if the link value is longer
   than SSIZE_MAX, return NULL (caller may use errno to diagnose).  */

char *
areadlink_with_size (char const *file, size_t size)
{
  /* Some buggy file systems report garbage in st_size.  Defend
     against them by ignoring outlandish st_size values in the initial
     memory allocation.  */
  size_t symlink_max = SYMLINK_MAX;
  size_t INITIAL_LIMIT_BOUND = 8 * 1024;
  size_t initial_limit = (symlink_max < INITIAL_LIMIT_BOUND
                          ? symlink_max + 1
                          : INITIAL_LIMIT_BOUND);

  /* The initial buffer size for the link value.  */
  size_t buf_size = size < initial_limit ? size + 1 : initial_limit;

  while (1)
    {
      ssize_t r;
      size_t link_length;
      char *buffer = malloc (buf_size);

      if (buffer == NULL)
        return NULL;
      r = readlink (file, buffer, buf_size);
      link_length = r;

      /* On AIX 5L v5.3 and HP-UX 11i v2 04/09, readlink returns -1
         with errno == ERANGE if the buffer is too small.  */
      if (r < 0 && errno != ERANGE)
        {
          int saved_errno = errno;
          free (buffer);
          errno = saved_errno;
          return NULL;
        }

      if (link_length < buf_size)
        {
          buffer[link_length] = 0;
          return buffer;
        }

      free (buffer);
      if (buf_size <= MAXSIZE / 2)
        buf_size *= 2;
      else if (buf_size < MAXSIZE)
        buf_size = MAXSIZE;
      else
        {
          errno = ENOMEM;
          return NULL;
        }
    }
}
