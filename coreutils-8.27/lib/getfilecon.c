/* wrap getfilecon, lgetfilecon, and fgetfilecon
   Copyright (C) 2009-2017 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, see <http://www.gnu.org/licenses/>.  */

/* written by Jim Meyering */

#include <config.h>

#include <selinux/selinux.h>

#include <sys/types.h>
#include <errno.h>
#include <string.h>

/* FIXME: remove this once there is an errno-gnu module
   that guarantees the definition of ENODATA.  */
#ifndef ENODATA
# define ENODATA ENOTSUP
#endif

#undef getfilecon
#undef lgetfilecon
#undef fgetfilecon
int getfilecon (char const *file, security_context_t *con);
int lgetfilecon (char const *file, security_context_t *con);
int fgetfilecon (int fd, security_context_t *con);

/* getfilecon, lgetfilecon, and fgetfilecon can all misbehave, be it
   via an old version of libselinux where these would return 0 and set the
   result context to NULL, or via a modern kernel+lib operating on a file
   from a disk whose attributes were set by a kernel from around 2006.
   In that latter case, the functions return a length of 10 for the
   "unlabeled" context.  Map both failures to a return value of -1, and
   set errno to ENOTSUP in the first case, and ENODATA in the latter.  */

static int
map_to_failure (int ret, security_context_t *con)
{
  if (ret == 0)
    {
      errno = ENOTSUP;
      return -1;
    }

  if (ret == 10 && strcmp (*con, "unlabeled") == 0)
    {
      freecon (*con);
      *con = NULL;
      errno = ENODATA;
      return -1;
    }

  return ret;
}

int
rpl_getfilecon (char const *file, security_context_t *con)
{
  int ret = getfilecon (file, con);
  return map_to_failure (ret, con);
}

int
rpl_lgetfilecon (char const *file, security_context_t *con)
{
  int ret = lgetfilecon (file, con);
  return map_to_failure (ret, con);
}

int
rpl_fgetfilecon (int fd, security_context_t *con)
{
  int ret = fgetfilecon (fd, con);
  return map_to_failure (ret, con);
}
