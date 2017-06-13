/* Duplicate an open file descriptor.

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

#include "config.h"

/* Specification.  */
#include <unistd.h>

#include <errno.h>

#include "msvc-inval.h"

#undef dup

#if HAVE_MSVC_INVALID_PARAMETER_HANDLER
static int
dup_nothrow (int fd)
{
  int result;

  TRY_MSVC_INVAL
    {
      result = dup (fd);
    }
  CATCH_MSVC_INVAL
    {
      result = -1;
      errno = EBADF;
    }
  DONE_MSVC_INVAL;

  return result;
}
#elif defined __KLIBC__
# include <fcntl.h>
# include <sys/stat.h>

# include <InnoTekLIBC/backend.h>

static int
dup_nothrow (int fd)
{
  int dupfd;
  struct stat sbuf;

  dupfd = dup (fd);
  if (dupfd == -1 && errno == ENOTSUP \
      && !fstat (fd, &sbuf) && S_ISDIR (sbuf.st_mode))
    {
      char path[_MAX_PATH];

      /* Get a path from fd */
      if (!__libc_Back_ioFHToPath (fd, path, sizeof (path)))
        dupfd = open (path, O_RDONLY);
    }

  return dupfd;
}
#else
# define dup_nothrow dup
#endif

int
rpl_dup (int fd)
{
  int result = dup_nothrow (fd);
#if REPLACE_FCHDIR
  if (result >= 0)
    result = _gl_register_dup (fd, result);
#endif
  return result;
}
