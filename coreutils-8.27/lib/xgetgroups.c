/* xgetgroups.c -- return a list of the groups a user or current process is in

   Copyright (C) 2007-2017 Free Software Foundation, Inc.

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

/* Extracted from coreutils' src/id.c. */

#include "config.h"

#include "mgetgroups.h"

#include <errno.h>

#include "xalloc.h"

/* Like mgetgroups, but call xalloc_die on allocation failure.  */

int
xgetgroups (char const *username, gid_t gid, gid_t **groups)
{
  int result = mgetgroups (username, gid, groups);
  if (result == -1 && errno == ENOMEM)
    xalloc_die ();
  return result;
}
