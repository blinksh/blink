/* isatty() replacement.
   Copyright (C) 2012-2017 Free Software Foundation, Inc.

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

/* Specification.  */
#include <unistd.h>

/* This replacement is enabled on native Windows.  */

#include <errno.h>

/* Get declarations of the Win32 API functions.  */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include "msvc-inval.h"

/* Get _get_osfhandle().  */
#include "msvc-nothrow.h"

static BOOL IsConsoleHandle (HANDLE h)
{
  DWORD mode;
  return GetConsoleMode (h, &mode) != 0;
}

#if HAVE_MSVC_INVALID_PARAMETER_HANDLER
static int
_isatty_nothrow (int fd)
{
  int result;

  TRY_MSVC_INVAL
    {
      result = _isatty (fd);
    }
  CATCH_MSVC_INVAL
    {
      result = 0;
    }
  DONE_MSVC_INVAL;

  return result;
}
#else
# define _isatty_nothrow _isatty
#endif

/* Determine whether FD refers to a console device.  Return 1 if yes.
   Return 0 and set errno if no. (ptsname_r relies on the errno value.)  */
int
isatty (int fd)
{
  HANDLE h = (HANDLE) _get_osfhandle (fd);
  if (h == INVALID_HANDLE_VALUE)
    {
      errno = EBADF;
      return 0;
    }
  /* _isatty (fd) tests whether GetFileType of the handle is FILE_TYPE_CHAR.
     But it does not set errno when it returns 0.  */
  if (_isatty_nothrow (fd))
    {
      if (IsConsoleHandle (h))
        return 1;
    }
  errno = ENOTTY;
  return 0;
}
