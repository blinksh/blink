/* Prototypes for openat-style fd-relative SELinux functions
   Copyright (C) 2007, 2009-2017 Free Software Foundation, Inc.

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

#include "selinux/selinux.h"
#include "selinux/context.h"

/* These are the dir-fd-relative variants of the functions without the
   "at" suffix.  For example, getfileconat (AT_FDCWD, file, &c) is usually
   equivalent to getfilecon (file, &c).  The emulation is accomplished
   by first attempting getfilecon ("/proc/self/fd/DIR_FD/FILE", &c).
   Failing that, simulate it via save_cwd/fchdir/getfilecon/restore_cwd.
   If either the save_cwd or the restore_cwd fails (relatively unlikely),
   then give a diagnostic and exit nonzero.  */

/* dir-fd-relative getfilecon.  Set *CON to the SELinux security context
   of the file specified by DIR_FD and FILE and return the length of *CON.
   DIR_FD and FILE are interpreted as for fstatat[*].  A non-NULL *CON
   must be freed with freecon.  Upon error, set *CON to NULL, set errno
   and return -1.
   [*] with flags=0 here, with flags=AT_SYMLINK_NOFOLLOW for lgetfileconat  */
int  getfileconat (int dir_fd, char const *file, security_context_t *con);

/* dir-fd-relative lgetfilecon.  This function is just like getfileconat,
   except when DIR_FD and FILE specify a symlink:  lgetfileconat operates on
   the symlink, while getfileconat operates on the referent of the symlink.  */
int lgetfileconat (int dir_fd, char const *file, security_context_t *con);

/* dir-fd-relative setfilecon.  Set the SELinux security context of
   the file specified by DIR_FD and FILE to CON.  DIR_FD and FILE are
   interpreted as for fstatat[*].  Upon success, return 0.
   Otherwise, return -1 and set errno.  */
int  setfileconat (int dir_fd, char const *file, security_context_t con);

/* dir-fd-relative lsetfilecon.  This function is just like setfileconat,
   except that rather than dereferencing a symlink, this function affects it. */
/* dir-fd-relative lsetfilecon.  This function is just like setfileconat,
   except when DIR_FD and FILE specify a symlink:  lsetfileconat operates on
   the symlink, while setfileconat operates on the referent of the symlink.  */
int lsetfileconat (int dir_fd, char const *file, security_context_t con);
