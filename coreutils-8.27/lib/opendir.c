/* Start reading the entries of a directory.
   Copyright (C) 2006-2017 Free Software Foundation, Inc.

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
#include <dirent.h>

#include <errno.h>
#include <stddef.h>

#if HAVE_OPENDIR

/* Override opendir(), to keep track of the open file descriptors.
   Needed because there is a function dirfd().  */

#else

# include <stdlib.h>

# include "dirent-private.h"
# include "filename.h"

#endif

#if REPLACE_FCHDIR
# include <unistd.h>
#endif

#ifdef __KLIBC__
# include <io.h>
# include <fcntl.h>
#endif

DIR *
opendir (const char *dir_name)
{
#if HAVE_OPENDIR
# undef opendir
  DIR *dirp;

  dirp = opendir (dir_name);
  if (dirp == NULL)
    return NULL;

# ifdef __KLIBC__
  {
    int fd = open (dir_name, O_RDONLY);
    if (fd == -1 || _gl_register_dirp_fd (fd, dirp))
      {
        int saved_errno = errno;

        close (fd);
        closedir (dirp);

        errno = saved_errno;

        return NULL;
      }
  }
# endif
#else

  char dir_name_mask[MAX_PATH + 1 + 1 + 1];
  int status;
  HANDLE current;
  WIN32_FIND_DATA entry;
  struct gl_directory *dirp;

  if (dir_name[0] == '\0')
    {
      errno = ENOENT;
      return NULL;
    }

  /* Make the dir_name absolute, so that we continue reading the same
     directory if the current directory changed between this opendir()
     call and a subsequent rewinddir() call.  */
  if (!GetFullPathName (dir_name, MAX_PATH, dir_name_mask, NULL))
    {
      errno = EINVAL;
      return NULL;
    }

  /* Append the mask.
     "*" and "*.*" appear to be equivalent.  */
  {
    char *p;

    p = dir_name_mask + strlen (dir_name_mask);
    if (p > dir_name_mask && !ISSLASH (p[-1]))
      *p++ = '\\';
    *p++ = '*';
    *p = '\0';
  }

  /* Start searching the directory.  */
  status = -1;
  current = FindFirstFile (dir_name_mask, &entry);
  if (current == INVALID_HANDLE_VALUE)
    {
      switch (GetLastError ())
        {
        case ERROR_FILE_NOT_FOUND:
          status = -2;
          break;
        case ERROR_PATH_NOT_FOUND:
          errno = ENOENT;
          return NULL;
        case ERROR_DIRECTORY:
          errno = ENOTDIR;
          return NULL;
        case ERROR_ACCESS_DENIED:
          errno = EACCES;
          return NULL;
        default:
          errno = EIO;
          return NULL;
        }
    }

  /* Allocate the result.  */
  dirp =
    (struct gl_directory *)
    malloc (offsetof (struct gl_directory, dir_name_mask[0])
            + strlen (dir_name_mask) + 1);
  if (dirp == NULL)
    {
      if (current != INVALID_HANDLE_VALUE)
        FindClose (current);
      errno = ENOMEM;
      return NULL;
    }
  dirp->status = status;
  dirp->current = current;
  if (status == -1)
    memcpy (&dirp->entry, &entry, sizeof (WIN32_FIND_DATA));
  strcpy (dirp->dir_name_mask, dir_name_mask);

#endif

#if REPLACE_FCHDIR
  {
    int fd = dirfd (dirp);
    if (0 <= fd && _gl_register_fd (fd, dir_name) != fd)
      {
        int saved_errno = errno;
        closedir (dirp);
        errno = saved_errno;
        return NULL;
      }
  }
#endif

  return dirp;
}
