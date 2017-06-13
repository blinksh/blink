/* This function serves as replacement for a missing fchownat function,
   as well as a work around for the fchownat bug in glibc-2.4:
    <http://lists.ubuntu.com/archives/ubuntu-users/2006-September/093218.html>
   when the buggy fchownat-with-AT_SYMLINK_NOFOLLOW operates on a symlink, it
   mistakenly affects the symlink referent, rather than the symlink itself.

   Copyright (C) 2006-2007, 2009-2017 Free Software Foundation, Inc.

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

#include <unistd.h>

#include <errno.h>
#include <string.h>

#include "openat.h"

#if !HAVE_FCHOWNAT

/* Replacement for Solaris' function by the same name.
   Invoke chown or lchown on file, FILE, using OWNER and GROUP, in the
   directory open on descriptor FD.  If FLAG is AT_SYMLINK_NOFOLLOW, then
   use lchown, otherwise, use chown.  If possible, do it without changing
   the working directory.  Otherwise, resort to using save_cwd/fchdir,
   then (chown|lchown)/restore_cwd.  If either the save_cwd or the
   restore_cwd fails, then give a diagnostic and exit nonzero.  */

# define AT_FUNC_NAME fchownat
# define AT_FUNC_F1 lchown
# define AT_FUNC_F2 chown
# define AT_FUNC_USE_F1_COND AT_SYMLINK_NOFOLLOW
# define AT_FUNC_POST_FILE_PARAM_DECLS , uid_t owner, gid_t group, int flag
# define AT_FUNC_POST_FILE_ARGS        , owner, group
# include "at-func.c"
# undef AT_FUNC_NAME
# undef AT_FUNC_F1
# undef AT_FUNC_F2
# undef AT_FUNC_USE_F1_COND
# undef AT_FUNC_POST_FILE_PARAM_DECLS
# undef AT_FUNC_POST_FILE_ARGS

#else /* HAVE_FCHOWNAT */

# undef fchownat

# if FCHOWNAT_NOFOLLOW_BUG

/* Failure to handle AT_SYMLINK_NOFOLLOW requires the /proc/self/fd or
   fchdir workaround to call lchown for lchownat, but there is no need
   to penalize chownat.  */
static int
local_lchownat (int fd, char const *file, uid_t owner, gid_t group);

#  define AT_FUNC_NAME local_lchownat
#  define AT_FUNC_F1 lchown
#  define AT_FUNC_POST_FILE_PARAM_DECLS , uid_t owner, gid_t group
#  define AT_FUNC_POST_FILE_ARGS        , owner, group
#  include "at-func.c"
#  undef AT_FUNC_NAME
#  undef AT_FUNC_F1
#  undef AT_FUNC_POST_FILE_PARAM_DECLS
#  undef AT_FUNC_POST_FILE_ARGS

# endif

/* Work around bugs with trailing slash, using the same workarounds as
   chown and lchown.  */

int
rpl_fchownat (int fd, char const *file, uid_t owner, gid_t group, int flag)
{
# if FCHOWNAT_NOFOLLOW_BUG
  if (flag == AT_SYMLINK_NOFOLLOW)
    return local_lchownat (fd, file, owner, group);
# endif
# if FCHOWNAT_EMPTY_FILENAME_BUG
  if (file[0] == '\0')
    {
      errno = ENOENT;
      return -1;
    }
# endif
# if CHOWN_TRAILING_SLASH_BUG
  {
    size_t len = strlen (file);
    struct stat st;
    if (len && file[len - 1] == '/')
      {
        if (statat (fd, file, &st))
          return -1;
        if (flag == AT_SYMLINK_NOFOLLOW)
          return fchownat (fd, file, owner, group, 0);
      }
  }
# endif
  return fchownat (fd, file, owner, group, flag);
}

#endif /* HAVE_FCHOWNAT */
