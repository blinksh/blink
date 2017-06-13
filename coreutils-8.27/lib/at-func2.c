/* Define 2-FD at-style functions like linkat or renameat.
   Copyright (C) 2006, 2009-2017 Free Software Foundation, Inc.

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

/* written by Jim Meyering and Eric Blake */

#include "config.h"

#include "openat-priv.h"

#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "dosname.h" /* solely for definition of IS_ABSOLUTE_FILE_NAME */
#include "filenamecat.h"
#include "openat.h"
#include "same-inode.h"
#include "save-cwd.h"

/* Call FUNC to operate on a pair of files, where FILE1 is relative to FD1,
   and FILE2 is relative to FD2.  If possible, do it without changing the
   working directory.  Otherwise, resort to using save_cwd/fchdir,
   FUNC, restore_cwd (up to two times).  If either the save_cwd or the
   restore_cwd fails, then give a diagnostic and exit nonzero.  */
int
at_func2 (int fd1, char const *file1,
          int fd2, char const *file2,
          int (*func) (char const *file1, char const *file2))
{
  struct saved_cwd saved_cwd;
  int saved_errno;
  int err;
  char *file1_alt;
  char *file2_alt;
  struct stat st1;
  struct stat st2;

  /* There are 16 possible scenarios, based on whether an fd is
     AT_FDCWD or real, and whether a file is absolute or relative:

         fd1  file1 fd2  file2  action
     0   cwd  abs   cwd  abs    direct call
     1   cwd  abs   cwd  rel    direct call
     2   cwd  abs   fd   abs    direct call
     3   cwd  abs   fd   rel    chdir to fd2
     4   cwd  rel   cwd  abs    direct call
     5   cwd  rel   cwd  rel    direct call
     6   cwd  rel   fd   abs    direct call
     7   cwd  rel   fd   rel    convert file1 to abs, then case 3
     8   fd   abs   cwd  abs    direct call
     9   fd   abs   cwd  rel    direct call
     10  fd   abs   fd   abs    direct call
     11  fd   abs   fd   rel    chdir to fd2
     12  fd   rel   cwd  abs    chdir to fd1
     13  fd   rel   cwd  rel    convert file2 to abs, then case 12
     14  fd   rel   fd   abs    chdir to fd1
     15a fd1  rel   fd1  rel    chdir to fd1
     15b fd1  rel   fd2  rel    chdir to fd1, then case 7

     Try some optimizations to reduce fd to AT_FDCWD, or to at least
     avoid converting an absolute name or doing a double chdir.  */

  if ((fd1 == AT_FDCWD || IS_ABSOLUTE_FILE_NAME (file1))
      && (fd2 == AT_FDCWD || IS_ABSOLUTE_FILE_NAME (file2)))
    return func (file1, file2); /* Case 0-2, 4-6, 8-10.  */

  /* If /proc/self/fd works, we don't need any stat or chdir.  */
  {
    char proc_buf1[OPENAT_BUFFER_SIZE];
    char *proc_file1 = ((fd1 == AT_FDCWD || IS_ABSOLUTE_FILE_NAME (file1))
                        ? (char *) file1
                        : openat_proc_name (proc_buf1, fd1, file1));
    if (proc_file1)
      {
        char proc_buf2[OPENAT_BUFFER_SIZE];
        char *proc_file2 = ((fd2 == AT_FDCWD || IS_ABSOLUTE_FILE_NAME (file2))
                            ? (char *) file2
                            : openat_proc_name (proc_buf2, fd2, file2));
        if (proc_file2)
          {
            int proc_result = func (proc_file1, proc_file2);
            int proc_errno = errno;
            if (proc_file1 != proc_buf1 && proc_file1 != file1)
              free (proc_file1);
            if (proc_file2 != proc_buf2 && proc_file2 != file2)
              free (proc_file2);
            /* If the syscall succeeds, or if it fails with an unexpected
               errno value, then return right away.  Otherwise, fall through
               and resort to using save_cwd/restore_cwd.  */
            if (0 <= proc_result)
              return proc_result;
            if (! EXPECTED_ERRNO (proc_errno))
              {
                errno = proc_errno;
                return proc_result;
              }
          }
        else if (proc_file1 != proc_buf1 && proc_file1 != file1)
          free (proc_file1);
      }
  }

  /* Cases 3, 7, 11-15 remain.  Time to normalize directory fds, if
     possible.  */
  if (IS_ABSOLUTE_FILE_NAME (file1))
    fd1 = AT_FDCWD; /* Case 11 reduced to 3.  */
  else if (IS_ABSOLUTE_FILE_NAME (file2))
    fd2 = AT_FDCWD; /* Case 14 reduced to 12.  */

  /* Cases 3, 7, 12, 13, 15 remain.  */

  if (fd1 == AT_FDCWD) /* Cases 3, 7.  */
    {
      if (stat (".", &st1) == -1 || fstat (fd2, &st2) == -1)
        return -1;
      if (!S_ISDIR (st2.st_mode))
        {
          errno = ENOTDIR;
          return -1;
        }
      if (SAME_INODE (st1, st2)) /* Reduced to cases 1, 5.  */
        return func (file1, file2);
    }
  else if (fd2 == AT_FDCWD) /* Cases 12, 13.  */
    {
      if (stat (".", &st2) == -1 || fstat (fd1, &st1) == -1)
        return -1;
      if (!S_ISDIR (st1.st_mode))
        {
          errno = ENOTDIR;
          return -1;
        }
      if (SAME_INODE (st1, st2)) /* Reduced to cases 4, 5.  */
        return func (file1, file2);
    }
  else if (fd1 != fd2) /* Case 15b.  */
    {
      if (fstat (fd1, &st1) == -1 || fstat (fd2, &st2) == -1)
        return -1;
      if (!S_ISDIR (st1.st_mode) || !S_ISDIR (st2.st_mode))
        {
          errno = ENOTDIR;
          return -1;
        }
      if (SAME_INODE (st1, st2)) /* Reduced to case 15a.  */
        {
          fd2 = fd1;
          if (stat (".", &st1) == 0 && SAME_INODE (st1, st2))
            return func (file1, file2); /* Further reduced to case 5.  */
        }
    }
  else /* Case 15a.  */
    {
      if (fstat (fd1, &st1) == -1)
        return -1;
      if (!S_ISDIR (st1.st_mode))
        {
          errno = ENOTDIR;
          return -1;
        }
      if (stat (".", &st2) == 0 && SAME_INODE (st1, st2))
        return func (file1, file2); /* Reduced to case 5.  */
    }

  /* Cases 3, 7, 12, 13, 15a, 15b remain.  With all reductions in
     place, it is time to start changing directories.  */

  if (save_cwd (&saved_cwd) != 0)
    openat_save_fail (errno);

  if (fd1 != AT_FDCWD && fd2 != AT_FDCWD && fd1 != fd2) /* Case 15b.  */
    {
      if (fchdir (fd1) != 0)
        {
          saved_errno = errno;
          free_cwd (&saved_cwd);
          errno = saved_errno;
          return -1;
        }
      fd1 = AT_FDCWD; /* Reduced to case 7.  */
    }

  /* Cases 3, 7, 12, 13, 15a remain.  Convert one relative name to
     absolute, if necessary.  */

  file1_alt = (char *) file1;
  file2_alt = (char *) file2;

  if (fd1 == AT_FDCWD && !IS_ABSOLUTE_FILE_NAME (file1)) /* Case 7.  */
    {
      /* It would be nicer to use:
         file1_alt = file_name_concat (xgetcwd (), file1, NULL);
         but libraries should not call xalloc_die.  */
      char *cwd = getcwd (NULL, 0);
      if (!cwd)
        {
          saved_errno = errno;
          free_cwd (&saved_cwd);
          errno = saved_errno;
          return -1;
        }
      file1_alt = mfile_name_concat (cwd, file1, NULL);
      if (!file1_alt)
        {
          saved_errno = errno;
          free (cwd);
          free_cwd (&saved_cwd);
          errno = saved_errno;
          return -1;
        }
      free (cwd); /* Reduced to case 3.  */
    }
  else if (fd2 == AT_FDCWD && !IS_ABSOLUTE_FILE_NAME (file2)) /* Case 13.  */
    {
      char *cwd = getcwd (NULL, 0);
      if (!cwd)
        {
          saved_errno = errno;
          free_cwd (&saved_cwd);
          errno = saved_errno;
          return -1;
        }
      file2_alt = mfile_name_concat (cwd, file2, NULL);
      if (!file2_alt)
        {
          saved_errno = errno;
          free (cwd);
          free_cwd (&saved_cwd);
          errno = saved_errno;
          return -1;
        }
      free (cwd); /* Reduced to case 12.  */
    }

  /* Cases 3, 12, 15a remain.  Change to the correct directory.  */
  if (fchdir (fd1 == AT_FDCWD ? fd2 : fd1) != 0)
    {
      saved_errno = errno;
      free_cwd (&saved_cwd);
      if (file1 != file1_alt)
        free (file1_alt);
      else if (file2 != file2_alt)
        free (file2_alt);
      errno = saved_errno;
      return -1;
    }

  /* Finally safe to perform the user's function, then clean up.  */

  err = func (file1_alt, file2_alt);
  saved_errno = (err < 0 ? errno : 0);

  if (file1 != file1_alt)
    free (file1_alt);
  else if (file2 != file2_alt)
    free (file2_alt);

  if (restore_cwd (&saved_cwd) != 0)
    openat_restore_fail (errno);

  free_cwd (&saved_cwd);

  if (saved_errno)
    errno = saved_errno;
  return err;
}
#undef CALL_FUNC
#undef FUNC_RESULT
