/* Emulate link on platforms that lack it, namely native Windows platforms.

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

#include "config.h"

#include <unistd.h>

#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#if !HAVE_LINK
# if (defined _WIN32 || defined __WIN32__) && ! defined __CYGWIN__

#  define WIN32_LEAN_AND_MEAN
#  include <windows.h>

/* CreateHardLink was introduced only in Windows 2000.  */
typedef BOOL (WINAPI * CreateHardLinkFuncType) (LPCTSTR lpFileName,
                                                LPCTSTR lpExistingFileName,
                                                LPSECURITY_ATTRIBUTES lpSecurityAttributes);
static CreateHardLinkFuncType CreateHardLinkFunc = NULL;
static BOOL initialized = FALSE;

static void
initialize (void)
{
  HMODULE kernel32 = GetModuleHandle ("kernel32.dll");
  if (kernel32 != NULL)
    {
      CreateHardLinkFunc =
        (CreateHardLinkFuncType) GetProcAddress (kernel32, "CreateHardLinkA");
    }
  initialized = TRUE;
}

int
link (const char *file1, const char *file2)
{
  char *dir;
  size_t len1 = strlen (file1);
  size_t len2 = strlen (file2);
  if (!initialized)
    initialize ();
  if (CreateHardLinkFunc == NULL)
    {
      /* System does not support hard links.  */
      errno = EPERM;
      return -1;
    }
  /* Reject trailing slashes on non-directories; mingw does not
     support hard-linking directories.  */
  if ((len1 && (file1[len1 - 1] == '/' || file1[len1 - 1] == '\\'))
      || (len2 && (file2[len2 - 1] == '/' || file2[len2 - 1] == '\\')))
    {
      struct stat st;
      if (stat (file1, &st) == 0 && S_ISDIR (st.st_mode))
        errno = EPERM;
      else
        errno = ENOTDIR;
      return -1;
    }
  /* CreateHardLink("b/.","a",NULL) creates file "b", so we must check
     that dirname(file2) exists.  */
  dir = strdup (file2);
  if (!dir)
    return -1;
  {
    struct stat st;
    char *p = strchr (dir, '\0');
    while (dir < p && (*--p != '/' && *p != '\\'));
    *p = '\0';
    if (p != dir && stat (dir, &st) == -1)
      {
        int saved_errno = errno;
        free (dir);
        errno = saved_errno;
        return -1;
      }
    free (dir);
  }
  /* Now create the link.  */
  if (CreateHardLinkFunc (file2, file1, NULL) == 0)
    {
      /* It is not documented which errors CreateHardLink() can produce.
       * The following conversions are based on tests on a Windows XP SP2
       * system. */
      DWORD err = GetLastError ();
      switch (err)
        {
        case ERROR_ACCESS_DENIED:
          errno = EACCES;
          break;

        case ERROR_INVALID_FUNCTION:    /* fs does not support hard links */
          errno = EPERM;
          break;

        case ERROR_NOT_SAME_DEVICE:
          errno = EXDEV;
          break;

        case ERROR_PATH_NOT_FOUND:
        case ERROR_FILE_NOT_FOUND:
          errno = ENOENT;
          break;

        case ERROR_INVALID_PARAMETER:
          errno = ENAMETOOLONG;
          break;

        case ERROR_TOO_MANY_LINKS:
          errno = EMLINK;
          break;

        case ERROR_ALREADY_EXISTS:
          errno = EEXIST;
          break;

        default:
          errno = EIO;
        }
      return -1;
    }

  return 0;
}

# else /* !Windows */

#  error "This platform lacks a link function, and Gnulib doesn't provide a replacement. This is a bug in Gnulib."

# endif /* !Windows */
#else /* HAVE_LINK */

# undef link

/* Create a hard link from FILE1 to FILE2, working around platform bugs.  */
int
rpl_link (char const *file1, char const *file2)
{
  size_t len1;
  size_t len2;
  struct stat st;

  /* Don't allow IRIX to dereference dangling file2 symlink.  */
  if (!lstat (file2, &st))
    {
      errno = EEXIST;
      return -1;
    }

  /* Reject trailing slashes on non-directories.  */
  len1 = strlen (file1);
  len2 = strlen (file2);
  if ((len1 && file1[len1 - 1] == '/')
      || (len2 && file2[len2 - 1] == '/'))
    {
      /* Let link() decide whether hard-linking directories is legal.
         If stat() fails, then link() should fail for the same reason
         (although on Solaris 9, link("file/","oops") mistakenly
         succeeds); if stat() succeeds, require a directory.  */
      if (stat (file1, &st))
        return -1;
      if (!S_ISDIR (st.st_mode))
        {
          errno = ENOTDIR;
          return -1;
        }
    }
  else
    {
      /* Fix Cygwin 1.5.x bug where link("a","b/.") creates file "b".  */
      char *dir = strdup (file2);
      char *p;
      if (!dir)
        return -1;
      /* We already know file2 does not end in slash.  Strip off the
         basename, then check that the dirname exists.  */
      p = strrchr (dir, '/');
      if (p)
        {
          *p = '\0';
          if (stat (dir, &st) == -1)
            {
              int saved_errno = errno;
              free (dir);
              errno = saved_errno;
              return -1;
            }
        }
      free (dir);
    }
  return link (file1, file2);
}
#endif /* HAVE_LINK */
