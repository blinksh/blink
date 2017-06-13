/* Create a hard link relative to open directories.
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

/* written by Eric Blake */

#include "config.h"

#include <unistd.h>

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#include "areadlink.h"
#include "dirname.h"
#include "filenamecat.h"
#include "openat-priv.h"

#if HAVE_SYS_PARAM_H
# include <sys/param.h>
#endif
#ifndef MAXSYMLINKS
# ifdef SYMLOOP_MAX
#  define MAXSYMLINKS SYMLOOP_MAX
# else
#  define MAXSYMLINKS 20
# endif
#endif

#if !HAVE_LINKAT || LINKAT_SYMLINK_NOTSUP

/* Create a link.  If FILE1 is a symlink, either create a hardlink to
   that symlink, or fake it by creating an identical symlink.  */
# if LINK_FOLLOWS_SYMLINKS == 0
#  define link_immediate link
# else
static int
link_immediate (char const *file1, char const *file2)
{
  char *target = areadlink (file1);
  if (target)
    {
      /* A symlink cannot be modified in-place.  Therefore, creating
         an identical symlink behaves like a hard link to a symlink,
         except for incorrect st_ino and st_nlink.  However, we must
         be careful of EXDEV.  */
      struct stat st1;
      struct stat st2;
      char *dir = mdir_name (file2);
      if (!dir)
        {
          free (target);
          errno = ENOMEM;
          return -1;
        }
      if (lstat (file1, &st1) == 0 && stat (dir, &st2) == 0)
        {
          if (st1.st_dev == st2.st_dev)
            {
              int result = symlink (target, file2);
              int saved_errno = errno;
              free (target);
              free (dir);
              errno = saved_errno;
              return result;
            }
          free (target);
          free (dir);
          errno = EXDEV;
          return -1;
        }
      free (target);
      free (dir);
    }
  if (errno == ENOMEM)
    return -1;
  return link (file1, file2);
}
# endif /* LINK_FOLLOWS_SYMLINKS == 0 */

/* Create a link.  If FILE1 is a symlink, create a hardlink to the
   canonicalized file.  */
# if 0 < LINK_FOLLOWS_SYMLINKS
#  define link_follow link
# else
static int
link_follow (char const *file1, char const *file2)
{
  char *name = (char *) file1;
  char *target;
  int result;
  int i = MAXSYMLINKS;

  /* Using realpath or canonicalize_file_name is too heavy-handed: we
     don't need an absolute name, and we don't need to resolve
     intermediate symlinks, just the basename of each iteration.  */
  while (i-- && (target = areadlink (name)))
    {
      if (IS_ABSOLUTE_FILE_NAME (target))
        {
          if (name != file1)
            free (name);
          name = target;
        }
      else
        {
          char *dir = mdir_name (name);
          if (name != file1)
            free (name);
          if (!dir)
            {
              free (target);
              errno = ENOMEM;
              return -1;
            }
          name = mfile_name_concat (dir, target, NULL);
          free (dir);
          free (target);
          if (!name)
            {
              errno = ENOMEM;
              return -1;
            }
        }
    }
  if (i < 0)
    {
      target = NULL;
      errno = ELOOP;
    }
  if (!target && errno != EINVAL)
    {
      if (name != file1)
        {
          int saved_errno = errno;
          free (name);
          errno = saved_errno;
        }
      return -1;
    }
  result = link (name, file2);
  if (name != file1)
    {
      int saved_errno = errno;
      free (name);
      errno = saved_errno;
    }
  return result;
}
# endif /* 0 < LINK_FOLLOWS_SYMLINKS */

/* On Solaris, link() doesn't follow symlinks by default, but does so as soon
   as a library or executable takes part in the program that has been compiled
   with "c99" or "cc -xc99=all" or "cc ... /usr/lib/values-xpg4.o ...".  */
# if LINK_FOLLOWS_SYMLINKS == -1

/* Reduce the penalty of link_immediate and link_follow by incorporating the
   knowledge that link()'s behaviour depends on the __xpg4 variable.  */
extern int __xpg4;

static int
solaris_optimized_link_immediate (char const *file1, char const *file2)
{
  if (__xpg4 == 0)
    return link (file1, file2);
  return link_immediate (file1, file2);
}

static int
solaris_optimized_link_follow (char const *file1, char const *file2)
{
  if (__xpg4 != 0)
    return link (file1, file2);
  return link_follow (file1, file2);
}

#  define link_immediate solaris_optimized_link_immediate
#  define link_follow solaris_optimized_link_follow

# endif

#endif /* !HAVE_LINKAT || LINKAT_SYMLINK_NOTSUP  */

#if !HAVE_LINKAT

/* Create a link to FILE1, in the directory open on descriptor FD1, to FILE2,
   in the directory open on descriptor FD2.  If FILE1 is a symlink, FLAG
   controls whether to dereference FILE1 first.  If possible, do it without
   changing the working directory.  Otherwise, resort to using
   save_cwd/fchdir, then rename/restore_cwd.  If either the save_cwd or
   the restore_cwd fails, then give a diagnostic and exit nonzero.  */

int
linkat (int fd1, char const *file1, int fd2, char const *file2, int flag)
{
  if (flag & ~AT_SYMLINK_FOLLOW)
    {
      errno = EINVAL;
      return -1;
    }
  return at_func2 (fd1, file1, fd2, file2,
                   flag ? link_follow : link_immediate);
}

#else /* HAVE_LINKAT */

# undef linkat

/* Create a link.  If FILE1 is a symlink, create a hardlink to the
   canonicalized file.  */

static int
linkat_follow (int fd1, char const *file1, int fd2, char const *file2)
{
  char *name = (char *) file1;
  char *target;
  int result;
  int i = MAXSYMLINKS;

  /* There is no realpathat.  */
  while (i-- && (target = areadlinkat (fd1, name)))
    {
      if (IS_ABSOLUTE_FILE_NAME (target))
        {
          if (name != file1)
            free (name);
          name = target;
        }
      else
        {
          char *dir = mdir_name (name);
          if (name != file1)
            free (name);
          if (!dir)
            {
              free (target);
              errno = ENOMEM;
              return -1;
            }
          name = mfile_name_concat (dir, target, NULL);
          free (dir);
          free (target);
          if (!name)
            {
              errno = ENOMEM;
              return -1;
            }
        }
    }
  if (i < 0)
    {
      target = NULL;
      errno = ELOOP;
    }
  if (!target && errno != EINVAL)
    {
      if (name != file1)
        {
          int saved_errno = errno;
          free (name);
          errno = saved_errno;
        }
      return -1;
    }
  result = linkat (fd1, name, fd2, file2, 0);
  if (name != file1)
    {
      int saved_errno = errno;
      free (name);
      errno = saved_errno;
    }
  return result;
}


/* Like linkat, but guarantee that AT_SYMLINK_FOLLOW works even on
   older Linux kernels.  */

int
rpl_linkat (int fd1, char const *file1, int fd2, char const *file2, int flag)
{
  if (flag & ~AT_SYMLINK_FOLLOW)
    {
      errno = EINVAL;
      return -1;
    }

# if LINKAT_TRAILING_SLASH_BUG
  /* Reject trailing slashes on non-directories.  */
  {
    size_t len1 = strlen (file1);
    size_t len2 = strlen (file2);
    if ((len1 && file1[len1 - 1] == '/')
        || (len2 && file2[len2 - 1] == '/'))
      {
        /* Let linkat() decide whether hard-linking directories is legal.
           If fstatat() fails, then linkat() should fail for the same reason;
           if fstatat() succeeds, require a directory.  */
        struct stat st;
        if (fstatat (fd1, file1, &st, flag ? 0 : AT_SYMLINK_NOFOLLOW))
          return -1;
        if (!S_ISDIR (st.st_mode))
          {
            errno = ENOTDIR;
            return -1;
          }
      }
  }
# endif

  if (!flag)
    {
      int result = linkat (fd1, file1, fd2, file2, flag);
# if LINKAT_SYMLINK_NOTSUP
      /* OS X 10.10 has linkat() but it doesn't support
         hardlinks to symlinks.  Fallback to our emulation
         in that case.  */
      if (result == -1 && (errno == ENOTSUP || errno == EOPNOTSUPP))
        return at_func2 (fd1, file1, fd2, file2, link_immediate);
# endif
      return result;
    }

  /* Cache the information on whether the system call really works.  */
  {
    static int have_follow_really; /* 0 = unknown, 1 = yes, -1 = no */
    if (0 <= have_follow_really)
    {
      int result = linkat (fd1, file1, fd2, file2, flag);
      if (!(result == -1 && errno == EINVAL))
        {
          have_follow_really = 1;
          return result;
        }
      have_follow_really = -1;
    }
  }
  return linkat_follow (fd1, file1, fd2, file2);
}

#endif /* HAVE_LINKAT */
