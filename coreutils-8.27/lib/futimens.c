/* Set the access and modification time of an open fd.
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

#include "utimens.h"

/* Set the access and modification timestamps of FD to be
   TIMESPEC[0] and TIMESPEC[1], respectively.
   Fail with ENOSYS on systems without futimes (or equivalent).
   If TIMESPEC is null, set the timestamps to the current time.
   Return 0 on success, -1 (setting errno) on failure.  */
int
futimens (int fd, struct timespec const times[2])
{
  /* fdutimens also works around bugs in native futimens, when running
     with glibc compiled against newer headers but on a Linux kernel
     older than 2.6.32.  */
  return fdutimens (fd, NULL, times);
}
