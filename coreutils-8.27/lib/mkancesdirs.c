/* Make a file's ancestor directories.

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

/* Written by Paul Eggert.  */

#include "config.h"

#include "mkancesdirs.h"

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <errno.h>
#include <unistd.h>

#include "dirname.h"
#include "savewd.h"

/* Ensure that the ancestor directories of FILE exist, using an
   algorithm that should work even if two processes execute this
   function in parallel.  Modify FILE as necessary to access the
   ancestor directories, but restore FILE to an equivalent value
   if successful.

   WD points to the working directory, using the conventions of
   savewd.

   Create any ancestor directories that don't already exist, by
   invoking MAKE_DIR (FILE, COMPONENT, MAKE_DIR_ARG).  This function
   should return 0 if successful, -1 (setting errno) otherwise.  If
   COMPONENT is relative, it is relative to the temporary working
   directory, which may differ from *WD.

   Ordinarily MAKE_DIR is executed with the working directory changed
   to reflect the already-made prefix, and mkancesdirs returns with
   the working directory changed a prefix of FILE.  However, if the
   initial working directory cannot be saved in a file descriptor,
   MAKE_DIR is invoked in a subprocess and this function returns in
   both the parent and child process, so the caller should not assume
   any changed state survives other than the EXITMAX component of WD,
   and the caller should take care that the parent does not attempt to
   do the work that the child is doing.

   If successful and if this process can go ahead and create FILE,
   return the length of the prefix of FILE that has already been made.
   If successful so far but a child process is doing the actual work,
   return -2.  If unsuccessful, return -1 and set errno.  */

ptrdiff_t
mkancesdirs (char *file, struct savewd *wd,
             int (*make_dir) (char const *, char const *, void *),
             void *make_dir_arg)
{
  /* Address of the previous directory separator that follows an
     ordinary byte in a file name in the left-to-right scan, or NULL
     if no such separator precedes the current location P.  */
  char *sep = NULL;

  /* Address of the leftmost file name component that has not yet
     been processed.  */
  char *component = file;

  char *p = file + FILE_SYSTEM_PREFIX_LEN (file);
  char c;
  bool made_dir = false;

  /* Scan forward through FILE, creating and chdiring into directories
     along the way.  Try MAKE_DIR before chdir, so that the procedure
     works even when two or more processes are executing it in
     parallel.  Isolate each file name component by having COMPONENT
     point to its start and SEP point just after its end.  */

  while ((c = *p++))
    if (ISSLASH (*p))
      {
        if (! ISSLASH (c))
          sep = p;
      }
    else if (ISSLASH (c) && *p && sep)
      {
        /* Don't bother to make or test for "." since it does not
           affect the algorithm.  */
        if (! (sep - component == 1 && component[0] == '.'))
          {
            int make_dir_errno = 0;
            int savewd_chdir_options = 0;
            int chdir_result;

            /* Temporarily modify FILE to isolate this file name
               component.  */
            *sep = '\0';

            /* Invoke MAKE_DIR on this component, except don't bother
               with ".." since it must exist if its "parent" does.  */
            if (sep - component == 2
                && component[0] == '.' && component[1] == '.')
              made_dir = false;
            else if (make_dir (file, component, make_dir_arg) < 0)
              make_dir_errno = errno;
            else
              made_dir = true;

            if (made_dir)
              savewd_chdir_options |= SAVEWD_CHDIR_NOFOLLOW;

            chdir_result =
              savewd_chdir (wd, component, savewd_chdir_options, NULL);

            /* Undo the temporary modification to FILE, unless there
               was a failure.  */
            if (chdir_result != -1)
              *sep = '/';

            if (chdir_result != 0)
              {
                if (make_dir_errno != 0 && errno == ENOENT)
                  errno = make_dir_errno;
                return chdir_result;
              }
          }

        component = p;
      }

  return component - file;
}
