/* Save and restore the working directory, possibly using a subprocess.

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

#ifndef SAVEWD_H
# define SAVEWD_H 1

#include <stdbool.h>
#include <sys/types.h>

#ifndef _GL_INLINE_HEADER_BEGIN
 #error "Please include config.h first."
#endif
_GL_INLINE_HEADER_BEGIN
#ifndef SAVEWD_INLINE
# define SAVEWD_INLINE _GL_INLINE
#endif

/* A saved working directory.  The member names and constants defined
   by this structure are private to the savewd module.  */
struct savewd
{
  /* The state of this object.  */
  enum
    {
      /* This object has been created but does not yet represent
         the working directory.  */
      INITIAL_STATE,

      /* val.fd is the original working directory's file descriptor.
         It is still the working directory.  */
      FD_STATE,

      /* Like FD_STATE, but the working directory has changed, so
         restoring it will require a fchdir.  */
      FD_POST_CHDIR_STATE,

      /* Fork and let the subprocess do the work.  val.child is 0 in a
         child, negative in a childless parent, and the child process
         ID in a parent with a child.  */
      FORKING_STATE,

      /* A serious problem argues against further efforts.  val.errnum
         contains the error number (e.g., EIO).  */
      ERROR_STATE,

      /* savewd_finish has been called, so the application no longer
         cares whether the working directory is saved, and there is no
         more work to do.  */
      FINAL_STATE
    } state;

  /* The object's value.  */
  union
  {
    int fd;
    int errnum;
    pid_t child;
  } val;
};

/* Initialize a saved working directory object.  */
SAVEWD_INLINE void
savewd_init (struct savewd *wd)
{
  wd->state = INITIAL_STATE;
}


/* Options for savewd_chdir.  Can be ORed together.  */
enum
  {
    /* Do not follow symbolic links, if supported.  */
    SAVEWD_CHDIR_NOFOLLOW = 1,

    /* Do not chdir if the directory is readable; simply succeed
       without invoking chdir if the directory was opened.  */
    SAVEWD_CHDIR_SKIP_READABLE = 2
  };

/* Change the directory, and if successful, record into *WD the fact
   that the process chdired into DIR.  A process using this module
   should use savewd_chdir rather than chdir or fchdir.  Obey the
   options specified in OPTIONS.

   If OPEN_RESULT is not null, store into OPEN_RESULT[0] a file
   descriptor that accesses DIR if a file descriptor is successfully
   obtained.  Store -1 otherwise, setting OPEN_RESULT[1] to the error
   number.  Store through OPEN_RESULT regardless of whether the chdir
   is successful.  However, when -2 is returned, the contents of
   OPEN_RESULT are indeterminate since the file descriptor is closed
   in the parent.

   Return -2 if a subprocess was spun off to do the real work, -1
   (setting errno) if unsuccessful, 0 if successful.  */
int savewd_chdir (struct savewd *wd, char const *dir, int options,
                  int open_result[2]);

/* Restore the working directory from *WD.  STATUS indicates the exit
   status corresponding to the work done since the last save; this is
   used when the caller is in a subprocess.  Return 0 if successful,
   -1 (setting errno) on our failure, a positive subprocess exit
   status if the working directory was restored in the parent but the
   subprocess failed.  */
int savewd_restore (struct savewd *wd, int status);

/* Return WD's error number, or 0 if WD is not in an error state.  */
SAVEWD_INLINE int _GL_ATTRIBUTE_PURE
savewd_errno (struct savewd const *wd)
{
  return (wd->state == ERROR_STATE ? wd->val.errnum : 0);
}

/* Deallocate any resources associated with WD.  A program that chdirs
   should restore before finishing.  */
void savewd_finish (struct savewd *wd);

/* Process N_FILES file names, FILE[0] through FILE[N_FILES - 1].
   For each file name F, call ACT (F, WD, OPTIONS); ACT should invoke
   savewd_chdir as needed, and should return an exit status.  WD
   represents the working directory; it may be in an error state when
   ACT is called.

   Save and restore the working directory as needed by the file name
   vector; assume that ACT does not require access to any relative
   file names other than its first argument, and that it is OK if the
   working directory is changed when this function returns.  Some
   actions may be applied in a subprocess.

   Return the maximum exit status that any call to ACT returned, or
   EXIT_SUCCESS (i.e., 0) if no calls were made.  */
int savewd_process_files (int n_files, char **file,
                          int (*act) (char *, struct savewd *, void *),
                          void *options);

_GL_INLINE_HEADER_END

#endif
