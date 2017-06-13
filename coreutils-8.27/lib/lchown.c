/* Provide a stub lchown function for systems that lack it.

   Copyright (C) 1998-1999, 2002, 2004, 2006-2007, 2009-2017 Free Software
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

/* written by Jim Meyering */

#include "config.h"

#include <unistd.h>

#include <errno.h>
#include <stdbool.h>
#include <string.h>
#include <sys/stat.h>

#if !HAVE_LCHOWN

/* If the system chown does not follow symlinks, we don't want it
   replaced by gnulib's chown, which does follow symlinks.  */
# if CHOWN_MODIFIES_SYMLINK
#  undef chown
# endif

/* Work just like chown, except when FILE is a symbolic link.
   In that case, set errno to EOPNOTSUPP and return -1.
   But if autoconf tests determined that chown modifies
   symlinks, then just call chown.  */

int
lchown (const char *file, uid_t uid, gid_t gid)
{
# if HAVE_CHOWN
#  if ! CHOWN_MODIFIES_SYMLINK
  struct stat stats;

  if (lstat (file, &stats) == 0 && S_ISLNK (stats.st_mode))
    {
      errno = EOPNOTSUPP;
      return -1;
    }
#  endif

  return chown (file, uid, gid);

# else /* !HAVE_CHOWN */
  errno = ENOSYS;
  return -1;
# endif
}

#else /* HAVE_LCHOWN */

# undef lchown

/* Work around trailing slash bugs in lchown.  */
int
rpl_lchown (const char *file, uid_t uid, gid_t gid)
{
  bool stat_valid = false;
  int result;

# if CHOWN_CHANGE_TIME_BUG
  struct stat st;

  if (gid != (gid_t) -1 || uid != (uid_t) -1)
    {
      if (lstat (file, &st))
        return -1;
      stat_valid = true;
      if (!S_ISLNK (st.st_mode))
        return chown (file, uid, gid);
    }
# endif

# if CHOWN_TRAILING_SLASH_BUG
  if (!stat_valid)
    {
      size_t len = strlen (file);
      if (len && file[len - 1] == '/')
        return chown (file, uid, gid);
    }
# endif

  result = lchown (file, uid, gid);

# if CHOWN_CHANGE_TIME_BUG && HAVE_LCHMOD
  if (result == 0 && stat_valid
      && (uid == st.st_uid || uid == (uid_t) -1)
      && (gid == st.st_gid || gid == (gid_t) -1))
    {
      /* No change in ownership, but at least one argument was not -1,
         so we are required to update ctime.  Since lchown succeeded,
         we assume that lchmod will do likewise.  But if the system
         lacks lchmod and lutimes, we are out of luck.  Oh well.  */
      result = lchmod (file, st.st_mode & (S_IRWXU | S_IRWXG | S_IRWXO
                                           | S_ISUID | S_ISGID | S_ISVTX));
    }
# endif

  return result;
}

#endif /* HAVE_LCHOWN */
