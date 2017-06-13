/* savedir.c -- save the list of files in a directory in a string

   Copyright (C) 1990, 1997-2001, 2003-2006, 2009-2017 Free Software
   Foundation, Inc.

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

/* Written by David MacKenzie <djm@gnu.ai.mit.edu>. */

#include "config.h"

#include "savedir.h"

#include <sys/types.h>

#include <errno.h>

#include "dirent--.h"
#ifndef _D_EXACT_NAMLEN
# define _D_EXACT_NAMLEN(dp)    strlen ((dp)->d_name)
#endif

#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include "xalloc.h"

typedef struct
{
  char *name;
#if D_INO_IN_DIRENT
  ino_t ino;
#endif
} direntry_t;

/* Compare the names of two directory entries */

static int
direntry_cmp_name (void const *a, void const *b)
{
  direntry_t const *dea = a;
  direntry_t const *deb = b;

  return strcmp (dea->name, deb->name);
}

#if D_INO_IN_DIRENT
/* Compare the inode numbers of two directory entries */

static int
direntry_cmp_inode (void const *a, void const *b)
{
  direntry_t const *dea = a;
  direntry_t const *deb = b;

  return dea->ino < deb->ino ? -1 : dea->ino > deb->ino;
}
#endif

typedef int (*comparison_function) (void const *, void const *);

static comparison_function const comparison_function_table[] =
  {
    0,
    direntry_cmp_name
#if D_INO_IN_DIRENT
    , direntry_cmp_inode
#endif
  };

/* Return a freshly allocated string containing the file names
   in directory DIRP, separated by '\0' characters;
   the end is marked by two '\0' characters in a row.
   Returned values are sorted according to OPTION.
   Return NULL (setting errno) if DIRP cannot be read.
   If DIRP is NULL, return NULL without affecting errno.  */

char *
streamsavedir (DIR *dirp, enum savedir_option option)
{
  char *name_space = NULL;
  size_t allocated = 0;
  direntry_t *entries = NULL;
  size_t entries_allocated = 0;
  size_t entries_used = 0;
  size_t used = 0;
  int readdir_errno;
  comparison_function cmp = comparison_function_table[option];

  if (dirp == NULL)
    return NULL;

  for (;;)
    {
      struct dirent const *dp;
      char const *entry;

      errno = 0;
      dp = readdir (dirp);
      if (! dp)
        break;

      /* Skip "", ".", and "..".  "" is returned by at least one buggy
         implementation: Solaris 2.4 readdir on NFS file systems.  */
      entry = dp->d_name;
      if (entry[entry[0] != '.' ? 0 : entry[1] != '.' ? 1 : 2] != '\0')
        {
          size_t entry_size = _D_EXACT_NAMLEN (dp) + 1;
          if (cmp)
            {
              if (entries_allocated == entries_used)
                {
                  size_t n = entries_allocated;
                  entries = x2nrealloc (entries, &n, sizeof *entries);
                  entries_allocated = n;
                }
              entries[entries_used].name = xstrdup (entry);
#if D_INO_IN_DIRENT
              entries[entries_used].ino = dp->d_ino;
#endif
              entries_used++;
            }
          else
            {
              if (allocated - used <= entry_size)
                {
                  size_t n = used + entry_size;
                  if (n < used)
                    xalloc_die ();
                  name_space = x2nrealloc (name_space, &n, 1);
                  allocated = n;
                }
              memcpy (name_space + used, entry, entry_size);
            }
          used += entry_size;
        }
    }

  readdir_errno = errno;
  if (readdir_errno != 0)
    {
      free (entries);
      free (name_space);
      errno = readdir_errno;
      return NULL;
    }

  if (cmp)
    {
      size_t i;

      if (entries_used)
        qsort (entries, entries_used, sizeof *entries, cmp);
      name_space = xmalloc (used + 1);
      used = 0;
      for (i = 0; i < entries_used; i++)
        {
          char *dest = name_space + used;
          used += stpcpy (dest, entries[i].name) - dest + 1;
          free (entries[i].name);
        }
      free (entries);
    }
  else if (used == allocated)
    name_space = xrealloc (name_space, used + 1);

  name_space[used] = '\0';
  return name_space;
}

/* Return a freshly allocated string containing the file names
   in directory DIR, separated by '\0' characters;
   the end is marked by two '\0' characters in a row.
   Return NULL (setting errno) if DIR cannot be opened, read, or closed.  */

char *
savedir (char const *dir, enum savedir_option option)
{
  DIR *dirp = opendir (dir);
  if (! dirp)
    return NULL;
  else
    {
      char *name_space = streamsavedir (dirp, option);
      if (closedir (dirp) != 0)
        {
          int closedir_errno = errno;
          free (name_space);
          errno = closedir_errno;
          return NULL;
        }
      return name_space;
    }
}
