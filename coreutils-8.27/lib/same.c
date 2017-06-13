/* Determine whether two file names refer to the same file.

   Copyright (C) 1997-2000, 2002-2006, 2009-2017 Free Software Foundation, Inc.

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

/* written by Jim Meyering */

#include "config.h"

#include <stdbool.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <ctype.h>
#include <errno.h>

#include <string.h>

#include <limits.h>
#ifndef _POSIX_NAME_MAX
# define _POSIX_NAME_MAX 14
#endif

#include "same.h"
#include "dirname.h"
#include "error.h"
#include "same-inode.h"

#ifndef MIN
# define MIN(a, b) ((a) < (b) ? (a) : (b))
#endif

/* Return nonzero if SOURCE and DEST point to the same name in the same
   directory.  */

bool
same_name (const char *source, const char *dest)
{
  /* Compare the basenames.  */
  char const *source_basename = last_component (source);
  char const *dest_basename = last_component (dest);
  size_t source_baselen = base_len (source_basename);
  size_t dest_baselen = base_len (dest_basename);
  bool identical_basenames =
    (source_baselen == dest_baselen
     && memcmp (source_basename, dest_basename, dest_baselen) == 0);
  bool compare_dirs = identical_basenames;
  bool same = false;

#if ! _POSIX_NO_TRUNC && HAVE_PATHCONF && defined _PC_NAME_MAX
  /* This implementation silently truncates components of file names.  If
     the base names might be truncated, check whether the truncated
     base names are the same, while checking the directories.  */
  size_t slen_max = HAVE_LONG_FILE_NAMES ? 255 : _POSIX_NAME_MAX;
  size_t min_baselen = MIN (source_baselen, dest_baselen);
  if (slen_max <= min_baselen
      && memcmp (source_basename, dest_basename, slen_max) == 0)
    compare_dirs = true;
#endif

  if (compare_dirs)
    {
      struct stat source_dir_stats;
      struct stat dest_dir_stats;
      char *source_dirname, *dest_dirname;

      /* Compare the parent directories (via the device and inode numbers).  */
      source_dirname = dir_name (source);
      dest_dirname = dir_name (dest);

      if (stat (source_dirname, &source_dir_stats))
        {
          /* Shouldn't happen.  */
          error (1, errno, "%s", source_dirname);
        }

      if (stat (dest_dirname, &dest_dir_stats))
        {
          /* Shouldn't happen.  */
          error (1, errno, "%s", dest_dirname);
        }

      same = SAME_INODE (source_dir_stats, dest_dir_stats);

#if ! _POSIX_NO_TRUNC && HAVE_PATHCONF && defined _PC_NAME_MAX
      if (same && ! identical_basenames)
        {
          long name_max = (errno = 0, pathconf (dest_dirname, _PC_NAME_MAX));
          if (name_max < 0)
            {
              if (errno)
                {
                  /* Shouldn't happen.  */
                  error (1, errno, "%s", dest_dirname);
                }
              same = false;
            }
          else
            same = (name_max <= min_baselen
                    && memcmp (source_basename, dest_basename, name_max) == 0);
        }
#endif

      free (source_dirname);
      free (dest_dirname);
    }

  return same;
}
