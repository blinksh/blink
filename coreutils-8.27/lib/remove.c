/* Remove a file or directory.
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

#include <stdio.h>

#include <errno.h>
#include <unistd.h>

#undef remove

/* Remove NAME from the file system.  This works around C89 platforms
   that don't handle directories like POSIX requires; it also works
   around Solaris 9 bugs with trailing slash.  */
int
rpl_remove (char const *name)
{
  /* It is faster to just try rmdir, and fall back on unlink, than it
     is to use lstat to see what we are about to remove.  Technically,
     it is more likely that we want unlink, not rmdir, but we cannot
     guarantee the safety of unlink on directories.  Trailing slash
     bugs are handled by our rmdir and unlink wrappers.  */
  int result = rmdir (name);
  if (result && errno == ENOTDIR)
    result = unlink (name);
  return result;
}
