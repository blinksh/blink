/* Create a device inode.
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

#if !HAVE_MKNOD
/* Mingw lacks mknod; always fail with ENOSYS.  */

int
mknod (char const *name _GL_UNUSED, mode_t mode _GL_UNUSED,
       dev_t dev _GL_UNUSED)
{
  errno = ENOSYS;
  return -1;
}

#else /* HAVE_MKNOD */

# undef mknod

/* Create a file system node FILE, with access permissions and file
   type in MODE, and device type in DEV.  Usually, non-root
   applications can only create named fifos (mode includes S_IFIFO),
   with DEV set to 0.  Also work around trailing slash bugs.  */

int
rpl_mknod (char const *name, mode_t mode, dev_t dev)
{
# if MKFIFO_TRAILING_SLASH_BUG
  /* Trailing slash only makes sense for directories.  Of course,
     using mknod to create a directory is not very portable, so it may
     still fail later on.  */
  if (!S_ISDIR (mode))
    {
      size_t len = strlen (name);
      if (len && name[len - 1] == '/')
        {
          struct stat st;
          if (stat (name, &st) == 0)
            errno = EEXIST;
          return -1;
        }
    }
# endif
# if MKNOD_FIFO_BUG
  /* POSIX requires mknod to create fifos for non-privileged
     processes, but BSD implementations fail with EPERM.  */
  if (S_ISFIFO (mode) && dev == 0)
    return mkfifo (name, mode & ~S_IFIFO);
# endif
  return mknod (name, mode, dev);
}

#endif /* HAVE_MKNOD */
