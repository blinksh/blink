/* Invoke opendir, but avoid some glitches.

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

/* Written by Eric Blake.  */

#include "config.h"

#include "dirent-safer.h"

#include <errno.h>
#include <unistd.h>
#include "unistd-safer.h"

/* Like opendir, but do not clobber stdin, stdout, or stderr.  */

DIR *
opendir_safer (char const *name)
{
  DIR *dp = opendir (name);

  if (dp)
    {
      int fd = dirfd (dp);

      if (0 <= fd && fd <= STDERR_FILENO)
        {
          /* If fdopendir is native (as on Linux), then it is safe to
             assume dirfd(fdopendir(n))==n.  If we are using the
             gnulib module fdopendir, then this guarantee is not met,
             but fdopendir recursively calls opendir_safer up to 3
             times to at least get a safe fd.  If fdopendir is not
             present but dirfd is accurate (as on cygwin 1.5.x), then
             we recurse up to 3 times ourselves.  Finally, if dirfd
             always fails (as on mingw), then we are already safe.  */
          DIR *newdp;
          int e;
#if HAVE_FDOPENDIR || GNULIB_FDOPENDIR
          int f = dup_safer (fd);
          if (f < 0)
            {
              e = errno;
              newdp = NULL;
            }
          else
            {
              newdp = fdopendir (f);
              e = errno;
              if (! newdp)
                close (f);
            }
#else /* !FDOPENDIR */
          newdp = opendir_safer (name);
          e = errno;
#endif
          closedir (dp);
          errno = e;
          dp = newdp;
        }
    }

  return dp;
}
