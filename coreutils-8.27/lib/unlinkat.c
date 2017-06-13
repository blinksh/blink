/* Work around unlinkat bugs on Solaris 9 and Hurd.

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

/* Written by Eric Blake.  */

#include "config.h"

#include <unistd.h>

#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/stat.h>

#include <stdlib.h>

#include "dosname.h"
#include "openat.h"

#if HAVE_UNLINKAT

# undef unlinkat

/* unlinkat without AT_REMOVEDIR does not honor trailing / on Solaris 9.
   Hurd has the same issue.

   unlinkat without AT_REMOVEDIR erroneously ignores ".." on Darwin 14.

   Solve these in a similar manner to unlink.  */

int
rpl_unlinkat (int fd, char const *name, int flag)
{
  size_t len;
  int result = 0;
  /* rmdir behavior has no problems with trailing slash.  */
  if (flag & AT_REMOVEDIR)
    return unlinkat (fd, name, flag);

  len = strlen (name);
  if (len && ISSLASH (name[len - 1]))
    {
      /* See the lengthy comment in unlink.c why we disobey the POSIX
         rule of letting unlink("link-to-dir/") attempt to unlink a
         directory.  */
      struct stat st;
      result = lstatat (fd, name, &st);
      if (result == 0)
        {
          /* Trailing NUL will overwrite the trailing slash.  */
          char *short_name = malloc (len);
          if (!short_name)
            {
              errno = EPERM;
              return -1;
            }
          memcpy (short_name, name, len);
          while (len && ISSLASH (short_name[len - 1]))
            short_name[--len] = '\0';
          if (len && (lstatat (fd, short_name, &st) || S_ISLNK (st.st_mode)))
            {
              free (short_name);
              errno = EPERM;
              return -1;
            }
          free (short_name);
        }
    }
  if (!result)
    {
# if UNLINK_PARENT_BUG
      if (len >= 2 && name[len - 1] == '.' && name[len - 2] == '.'
          && (len == 2 || ISSLASH (name[len - 3])))
        {
          errno = EISDIR; /* could also use EPERM */
          return -1;
        }
# endif
      result = unlinkat (fd, name, flag);
    }
  return result;
}

#else /* !HAVE_UNLINKAT */

/* Replacement for Solaris' function by the same name.
   <http://www.google.com/search?q=unlinkat+site:docs.sun.com>
   First, try to simulate it via (unlink|rmdir) ("/proc/self/fd/FD/FILE").
   Failing that, simulate it via save_cwd/fchdir/(unlink|rmdir)/restore_cwd.
   If either the save_cwd or the restore_cwd fails (relatively unlikely),
   then give a diagnostic and exit nonzero.
   Otherwise, this function works just like Solaris' unlinkat.  */

# define AT_FUNC_NAME unlinkat
# define AT_FUNC_F1 rmdir
# define AT_FUNC_F2 unlink
# define AT_FUNC_USE_F1_COND AT_REMOVEDIR
# define AT_FUNC_POST_FILE_PARAM_DECLS , int flag
# define AT_FUNC_POST_FILE_ARGS        /* empty */
# include "at-func.c"
# undef AT_FUNC_NAME
# undef AT_FUNC_F1
# undef AT_FUNC_F2
# undef AT_FUNC_USE_F1_COND
# undef AT_FUNC_POST_FILE_PARAM_DECLS
# undef AT_FUNC_POST_FILE_ARGS

#endif /* !HAVE_UNLINKAT */
