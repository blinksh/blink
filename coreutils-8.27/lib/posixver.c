/* Which POSIX version to conform to, for utilities.

   Copyright (C) 2002-2006, 2009-2017 Free Software Foundation, Inc.

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

/* Written by Paul Eggert.  */

#include "config.h"

#include "posixver.h"

#include <limits.h>
#include <stdlib.h>

#include <unistd.h>
#ifndef _POSIX2_VERSION
# define _POSIX2_VERSION 0
#endif

#ifndef DEFAULT_POSIX2_VERSION
# define DEFAULT_POSIX2_VERSION _POSIX2_VERSION
#endif

/* The POSIX version that utilities should conform to.  The default is
   specified by the system.  */

int
posix2_version (void)
{
  long int v = DEFAULT_POSIX2_VERSION;
  char const *s = getenv ("_POSIX2_VERSION");

  if (s && *s)
    {
      char *e;
      long int i = strtol (s, &e, 10);
      if (! *e)
        v = i;
    }

  return v < INT_MIN ? INT_MIN : v < INT_MAX ? v : INT_MAX;
}
