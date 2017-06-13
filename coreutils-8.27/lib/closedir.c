/* Stop reading the entries of a directory.
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

#if REPLACE_FCHDIR
# include <unistd.h>
#endif

#if HAVE_CLOSEDIR

/* Override closedir(), to keep track of the open file descriptors.
   Needed because there is a function dirfd().  */

#else

# include <stdlib.h>

# include "dirent-private.h"

#endif

int
closedir (DIR *dirp)
{
# if REPLACE_FCHDIR || REPLACE_DIRFD
  int fd = dirfd (dirp);
# endif
  int retval;

#if HAVE_CLOSEDIR
# undef closedir

  retval = closedir (dirp);

# ifdef __KLIBC__
  if (!retval)
    _gl_unregister_dirp_fd (fd);
# endif
#else

  if (dirp->current != INVALID_HANDLE_VALUE)
    FindClose (dirp->current);
  free (dirp);

  retval = 0;

#endif

#if REPLACE_FCHDIR
  if (retval >= 0)
    _gl_unregister_fd (fd);
#endif
  return retval;
}
