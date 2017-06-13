/* provide consistent interface to getgroups for systems that don't allow N==0

   Copyright (C) 1996, 1999, 2003, 2006-2017 Free Software Foundation, Inc.

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

#include <unistd.h>

#include <errno.h>
#include <stdlib.h>
#include <stdint.h>

#if !HAVE_GETGROUPS

/* Provide a stub that fails with ENOSYS, since there is no group
   information available on mingw.  */
int
getgroups (int n _GL_UNUSED, GETGROUPS_T *groups _GL_UNUSED)
{
  errno = ENOSYS;
  return -1;
}

#else /* HAVE_GETGROUPS */

# undef getgroups
# ifndef GETGROUPS_ZERO_BUG
#  define GETGROUPS_ZERO_BUG 0
# endif

/* On OS X 10.6 and later, use the usual getgroups, not the one
   supplied when _DARWIN_C_SOURCE is defined.  _DARWIN_C_SOURCE is
   normally defined, since it means "conform to POSIX, but add
   non-POSIX extensions even if that violates the POSIX namespace
   rules", which is what we normally want.  But with getgroups there
   is an inconsistency, and _DARWIN_C_SOURCE means "change getgroups()
   so that it no longer works right".  The BUGS section of compat(5)
   says that the behavior is dubious if you compile different sections
   of a program with different _DARWIN_C_SOURCE settings, so fix only
   the offending symbol.  */
# ifdef __APPLE__
int posix_getgroups (int, gid_t []) __asm ("_getgroups");
#  define getgroups posix_getgroups
# endif

/* On at least Ultrix 4.3 and NextStep 3.2, getgroups (0, NULL) always
   fails.  On other systems, it returns the number of supplemental
   groups for the process.  This function handles that special case
   and lets the system-provided function handle all others.  However,
   it can fail with ENOMEM if memory is tight.  It is unspecified
   whether the effective group id is included in the list.  */

int
rpl_getgroups (int n, gid_t *group)
{
  int n_groups;
  GETGROUPS_T *gbuf;
  int saved_errno;

  if (n < 0)
    {
      errno = EINVAL;
      return -1;
    }

  if (n != 0 || !GETGROUPS_ZERO_BUG)
    {
      int result;
      if (sizeof *group == sizeof *gbuf)
        return getgroups (n, (GETGROUPS_T *) group);

      if (SIZE_MAX / sizeof *gbuf <= n)
        {
          errno = ENOMEM;
          return -1;
        }
      gbuf = malloc (n * sizeof *gbuf);
      if (!gbuf)
        return -1;
      result = getgroups (n, gbuf);
      if (0 <= result)
        {
          n = result;
          while (n--)
            group[n] = gbuf[n];
        }
      saved_errno = errno;
      free (gbuf);
      errno = saved_errno;
      return result;
    }

  n = 20;
  while (1)
    {
      /* No need to worry about address arithmetic overflow here,
         since the ancient systems that we're running on have low
         limits on the number of secondary groups.  */
      gbuf = malloc (n * sizeof *gbuf);
      if (!gbuf)
        return -1;
      n_groups = getgroups (n, gbuf);
      if (n_groups == -1 ? errno != EINVAL : n_groups < n)
        break;
      free (gbuf);
      n *= 2;
    }

  saved_errno = errno;
  free (gbuf);
  errno = saved_errno;

  return n_groups;
}

#endif /* HAVE_GETGROUPS */
