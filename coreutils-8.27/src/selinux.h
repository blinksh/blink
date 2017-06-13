/* selinux - core functions for maintaining SELinux labeling
   Copyright (C) 2012-2017 Free Software Foundation, Inc.

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

/* Written by Daniel Walsh <dwalsh@redhat.com> */

#ifndef COREUTILS_SELINUX_H
# define COREUTILS_SELINUX_H

/* Return true if ERR corresponds to an unsupported request,
   or if there is no context or it's inaccessible.  */
static inline bool
ignorable_ctx_err (int err)
{
  return err == ENOTSUP || err == ENODATA;
}

# if HAVE_SELINUX_SELINUX_H

extern bool
restorecon (char const *path, bool recurse, bool preserve);
extern int
defaultcon (char const *path, mode_t mode);

# else

static inline bool
restorecon (char const *path, bool recurse, bool preserve)
{ errno = ENOTSUP; return false; }

static inline int
defaultcon (char const *path, mode_t mode)
{ errno = ENOTSUP; return -1; }

# endif

#endif
