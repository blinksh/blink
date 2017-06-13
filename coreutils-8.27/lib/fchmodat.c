/* Change the protections of file relative to an open directory.
   Copyright (C) 2006, 2009-2017 Free Software Foundation, Inc.

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

#include <sys/stat.h>

#include <errno.h>

#ifndef HAVE_LCHMOD
/* Use a different name, to avoid conflicting with any
   system-supplied declaration.  */
# undef lchmod
# define lchmod lchmod_rpl
static int
lchmod (char const *f _GL_UNUSED, mode_t m _GL_UNUSED)
{
  errno = ENOSYS;
  return -1;
}
#endif

/* Solaris 10 has no function like this.
   Invoke chmod or lchmod on file, FILE, using mode MODE, in the directory
   open on descriptor FD.  If possible, do it without changing the
   working directory.  Otherwise, resort to using save_cwd/fchdir,
   then (chmod|lchmod)/restore_cwd.  If either the save_cwd or the
   restore_cwd fails, then give a diagnostic and exit nonzero.
   Note that an attempt to use a FLAG value of AT_SYMLINK_NOFOLLOW
   on a system without lchmod support causes this function to fail.  */

#define AT_FUNC_NAME fchmodat
#define AT_FUNC_F1 lchmod
#define AT_FUNC_F2 chmod
#define AT_FUNC_USE_F1_COND AT_SYMLINK_NOFOLLOW
#define AT_FUNC_POST_FILE_PARAM_DECLS , mode_t mode, int flag
#define AT_FUNC_POST_FILE_ARGS        , mode
#include "at-func.c"
