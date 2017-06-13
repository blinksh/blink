/* find-mount-point.c -- find the root mount point for a file.
   Copyright (C) 2010-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

#include <config.h>
#include <sys/types.h>

#include "system.h"
#include "die.h"
#include "error.h"
#include "save-cwd.h"
#include "xgetcwd.h"
#include "find-mount-point.h"

/* Return the root mountpoint of the file system on which FILE exists, in
   malloced storage.  FILE_STAT should be the result of stating FILE.
   Give a diagnostic and return NULL if unable to determine the mount point.
   Exit if unable to restore current working directory.  */
extern char *
find_mount_point (char const *file, struct stat const *file_stat)
{
  struct saved_cwd cwd;
  struct stat last_stat;
  char *mp = NULL;		/* The malloc'd mount point.  */

  if (save_cwd (&cwd) != 0)
    {
      error (0, errno, _("cannot get current directory"));
      return NULL;
    }

  if (S_ISDIR (file_stat->st_mode))
    /* FILE is a directory, so just chdir there directly.  */
    {
      last_stat = *file_stat;
      if (chdir (file) < 0)
        {
          error (0, errno, _("cannot change to directory %s"), quoteaf (file));
          return NULL;
        }
    }
  else
    /* FILE is some other kind of file; use its directory.  */
    {
      char *xdir = dir_name (file);
      char *dir;
      ASSIGN_STRDUPA (dir, xdir);
      free (xdir);

      if (chdir (dir) < 0)
        {
          error (0, errno, _("cannot change to directory %s"), quoteaf (dir));
          return NULL;
        }

      if (stat (".", &last_stat) < 0)
        {
          error (0, errno, _("cannot stat current directory (now %s)"),
                 quoteaf (dir));
          goto done;
        }
    }

  /* Now walk up FILE's parents until we find another file system or /,
     chdiring as we go.  LAST_STAT holds stat information for the last place
     we visited.  */
  while (true)
    {
      struct stat st;
      if (stat ("..", &st) < 0)
        {
          error (0, errno, _("cannot stat %s"), quoteaf (".."));
          goto done;
        }
      if (st.st_dev != last_stat.st_dev || st.st_ino == last_stat.st_ino)
        /* cwd is the mount point.  */
        break;
      if (chdir ("..") < 0)
        {
          error (0, errno, _("cannot change to directory %s"), quoteaf (".."));
          goto done;
        }
      last_stat = st;
    }

  /* Finally reached a mount point, see what it's called.  */
  mp = xgetcwd ();

done:
  /* Restore the original cwd.  */
  {
    int save_errno = errno;
    if (restore_cwd (&cwd) != 0)
      die (EXIT_FAILURE, errno,
           _("failed to return to initial working directory"));
    free_cwd (&cwd);
    errno = save_errno;
  }

  return mp;
}
