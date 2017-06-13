/* Set file access and modification times.

   Copyright (C) 2009-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by the
   Free Software Foundation; either version 3 of the License, or any
   later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* Written by Eric Blake.  */

/* derived from a function in utimens.c */

#include "config.h"

#include "utimens.h"

#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>

/* Set the access and modification timestamps of FD (a.k.a. FILE) to be
   TIMESPEC[0] and TIMESPEC[1], respectively; relative to directory DIR.
   FD must be either negative -- in which case it is ignored --
   or a file descriptor that is open on FILE.
   If FD is nonnegative, then FILE can be NULL, which means
   use just futimes (or equivalent) instead of utimes (or equivalent),
   and fail if on an old system without futimes (or equivalent).
   If TIMESPEC is null, set the timestamps to the current time.
   ATFLAG is passed to utimensat if FD is negative or futimens was
   unsupported, which can allow operation on FILE as a symlink.
   Return 0 on success, -1 (setting errno) on failure.  */

int
fdutimensat (int fd, int dir, char const *file, struct timespec const ts[2],
             int atflag)
{
  int result = 1;
  if (0 <= fd)
    result = futimens (fd, ts);
  if (file && (fd < 0 || (result == -1 && errno == ENOSYS)))
    result = utimensat (dir, file, ts, atflag);
  if (result == 1)
    {
      errno = EBADF;
      result = -1;
    }
  return result;
}
