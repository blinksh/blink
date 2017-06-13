/* xgetcwd.c -- return current directory with unlimited length

   Copyright (C) 2001, 2003-2004, 2006-2007, 2009-2017 Free Software
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

/* Written by Jim Meyering.  */

#include "config.h"

#include "xgetcwd.h"

#include <errno.h>
#include <unistd.h>

#include "xalloc.h"

/* Return the current directory, newly allocated.
   Upon an out-of-memory error, call xalloc_die.
   Upon any other type of error, return NULL.  */

char *
xgetcwd (void)
{
  char *cwd = getcwd (NULL, 0);
  if (! cwd && errno == ENOMEM)
    xalloc_die ();
  return cwd;
}
