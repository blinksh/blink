/* Create a named fifo.
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

/* written by Eric Blake */

#include "config.h"

#include <sys/stat.h>

#include <errno.h>
#include <string.h>

#if !HAVE_MKFIFO
/* Mingw lacks mkfifo; always fail with ENOSYS.  */

int
mkfifo (char const *name _GL_UNUSED, mode_t mode _GL_UNUSED)
{
  errno = ENOSYS;
  return -1;
}

#else /* HAVE_MKFIFO */

# undef mkfifo

/* Create a named fifo FILE, with access permissions in MODE.  Work
around trailing slash bugs.  */

int
rpl_mkfifo (char const *name, mode_t mode)
{
# if MKFIFO_TRAILING_SLASH_BUG
  size_t len = strlen (name);
  if (len && name[len - 1] == '/')
    {
      struct stat st;
      if (stat (name, &st) == 0)
        errno = EEXIST;
      return -1;
    }
# endif
  return mkfifo (name, mode);
}
#endif /* HAVE_MKFIFO */
