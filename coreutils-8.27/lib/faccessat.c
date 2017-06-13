/* Check the access rights of a file relative to an open directory.
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

#include "unistd.h"
#include <fcntl.h>

#ifndef HAVE_ACCESS
/* Mingw lacks access, but it also lacks real vs. effective ids, so
   the gnulib euidaccess module is good enough.  */
# undef access
# define access euidaccess
#endif

/* Invoke access or euidaccess on file, FILE, using mode MODE, in the directory
   open on descriptor FD.  If possible, do it without changing the
   working directory.  Otherwise, resort to using save_cwd/fchdir, then
   (access|euidaccess)/restore_cwd.  If either the save_cwd or the
   restore_cwd fails, then give a diagnostic and exit nonzero.
   Note that this implementation only supports AT_EACCESS, although some
   native versions also support AT_SYMLINK_NOFOLLOW.  */

#define AT_FUNC_NAME faccessat
#define AT_FUNC_F1 euidaccess
#define AT_FUNC_F2 access
#define AT_FUNC_USE_F1_COND AT_EACCESS
#define AT_FUNC_POST_FILE_PARAM_DECLS , int mode, int flag
#define AT_FUNC_POST_FILE_ARGS        , mode
#include "at-func.c"
