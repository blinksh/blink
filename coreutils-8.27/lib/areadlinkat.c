/* areadlinkat.c -- readlinkat wrapper to return malloc'd link name
   Unlike xreadlinkat, only call exit on failure to change directory.

   Copyright (C) 2001, 2003-2007, 2009-2017 Free Software Foundation, Inc.

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

/* Written by Jim Meyering <jim@meyering.net>,
   and Bruno Haible <bruno@clisp.org>,
   and Eric Blake <ebb9@byu.net>.  */

#include "config.h"

/* Specification.  */
#include "areadlink.h"

#include "careadlinkat.h"

#if HAVE_READLINKAT

/* Call readlinkat to get the symbolic link value of FILENAME relative to FD.
   Return a pointer to that NUL-terminated string in malloc'd storage.
   If readlinkat fails, return NULL and set errno (although failure to
   change directory will issue a diagnostic and exit).
   If allocation fails, or if the link value is longer than SIZE_MAX :-),
   return NULL and set errno to ENOMEM.  */

char *
areadlinkat (int fd, char const *filename)
{
  return careadlinkat (fd, filename, NULL, 0, NULL, readlinkat);
}

#else /* !HAVE_READLINKAT */

/* It is more efficient to change directories only once and call
   areadlink, rather than repeatedly call the replacement
   readlinkat.  */

# define AT_FUNC_NAME areadlinkat
# define AT_FUNC_F1 areadlink
# define AT_FUNC_POST_FILE_PARAM_DECLS /* empty */
# define AT_FUNC_POST_FILE_ARGS        /* empty */
# define AT_FUNC_RESULT char *
# define AT_FUNC_FAIL NULL
# include "at-func.c"
# undef AT_FUNC_NAME
# undef AT_FUNC_F1
# undef AT_FUNC_POST_FILE_PARAM_DECLS
# undef AT_FUNC_POST_FILE_ARGS
# undef AT_FUNC_RESULT
# undef AT_FUNC_FAIL

#endif /* !HAVE_READLINKAT */
