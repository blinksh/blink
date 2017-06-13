/* openat-style fd-relative functions for SE Linux
   Copyright (C) 2007, 2009-2017 Free Software Foundation, Inc.

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

/* written by Jim Meyering */

#include "config.h"

#include "selinux-at.h"
#include "openat.h"

#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>

#include "save-cwd.h"

#include "openat-priv.h"

#define AT_FUNC_NAME getfileconat
#define AT_FUNC_F1 getfilecon
#define AT_FUNC_POST_FILE_PARAM_DECLS , security_context_t *con
#define AT_FUNC_POST_FILE_ARGS        , con
#include "at-func.c"
#undef AT_FUNC_NAME
#undef AT_FUNC_F1
#undef AT_FUNC_POST_FILE_PARAM_DECLS
#undef AT_FUNC_POST_FILE_ARGS

#define AT_FUNC_NAME lgetfileconat
#define AT_FUNC_F1 lgetfilecon
#define AT_FUNC_POST_FILE_PARAM_DECLS , security_context_t *con
#define AT_FUNC_POST_FILE_ARGS        , con
#include "at-func.c"
#undef AT_FUNC_NAME
#undef AT_FUNC_F1
#undef AT_FUNC_POST_FILE_PARAM_DECLS
#undef AT_FUNC_POST_FILE_ARGS

#define AT_FUNC_NAME setfileconat
#define AT_FUNC_F1 setfilecon
#define AT_FUNC_POST_FILE_PARAM_DECLS , security_context_t con
#define AT_FUNC_POST_FILE_ARGS        , con
#include "at-func.c"
#undef AT_FUNC_NAME
#undef AT_FUNC_F1
#undef AT_FUNC_POST_FILE_PARAM_DECLS
#undef AT_FUNC_POST_FILE_ARGS

#define AT_FUNC_NAME lsetfileconat
#define AT_FUNC_F1 lsetfilecon
#define AT_FUNC_POST_FILE_PARAM_DECLS , security_context_t con
#define AT_FUNC_POST_FILE_ARGS        , con
#include "at-func.c"
#undef AT_FUNC_NAME
#undef AT_FUNC_F1
#undef AT_FUNC_POST_FILE_PARAM_DECLS
#undef AT_FUNC_POST_FILE_ARGS
