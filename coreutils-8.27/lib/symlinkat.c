/* Create a symlink relative to an open directory.
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

#include <unistd.h>
#include <errno.h>

#if HAVE_SYMLINKAT
# undef symlinkat

#include <sys/stat.h>
#include <string.h>

/* Create a symlink, but reject trailing slash.  */
int
rpl_symlinkat (char const *contents, int fd, char const *name)
{
  size_t len = strlen (name);
  if (len && name[len - 1] == '/')
    {
      struct stat st;
      if (fstatat (fd, name, &st, 0) == 0)
        errno = EEXIST;
      return -1;
    }
  return symlinkat (contents, fd, name);
}

#elif !HAVE_SYMLINK
/* Mingw lacks symlink, and it is more efficient to provide a trivial
   wrapper than to go through at-func.c to call rpl_symlink.  */

int
symlinkat (char const *path1 _GL_UNUSED, int fd _GL_UNUSED,
           char const *path2 _GL_UNUSED)
{
  errno = ENOSYS;
  return -1;
}

#else /* HAVE_SYMLINK */

/* Our openat helper functions expect the directory parameter first,
   not second.  These shims make life easier.  */

/* Like symlink, but with arguments reversed.  */
static int
symlink_reversed (char const *file, char const *contents)
{
  return symlink (contents, file);
}

/* Like symlinkat, but with arguments reversed.  */

static int
symlinkat_reversed (int fd, char const *file, char const *contents);

# define AT_FUNC_NAME symlinkat_reversed
# define AT_FUNC_F1 symlink_reversed
# define AT_FUNC_POST_FILE_PARAM_DECLS , char const *contents
# define AT_FUNC_POST_FILE_ARGS        , contents
# include "at-func.c"
# undef AT_FUNC_NAME
# undef AT_FUNC_F1
# undef AT_FUNC_POST_FILE_PARAM_DECLS
# undef AT_FUNC_POST_FILE_ARGS

/* Create a symlink FILE, in the directory open on descriptor FD,
   holding CONTENTS.  If possible, do it without changing the
   working directory.  Otherwise, resort to using save_cwd/fchdir,
   then symlink/restore_cwd.  If either the save_cwd or the restore_cwd
   fails, then give a diagnostic and exit nonzero.  */

int
symlinkat (char const *contents, int fd, char const *file)
{
  return symlinkat_reversed (fd, file, contents);
}

#endif /* HAVE_SYMLINK */
