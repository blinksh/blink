/* euidaccess -- check if effective user id can access file

   Copyright (C) 1990-1991, 1995, 1998, 2000, 2003-2006, 2008-2017 Free
   Software Foundation, Inc.

   This file is part of the GNU C Library.

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

/* Written by David MacKenzie and Torbjorn Granlund.
   Adapted for GNU C library by Roland McGrath.  */

#ifndef _LIBC
# include "config.h"
#endif

#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

#include "root-uid.h"

#if HAVE_LIBGEN_H
# include <libgen.h>
#endif

#include <errno.h>
#ifndef __set_errno
# define __set_errno(val) errno = (val)
#endif

#if defined EACCES && !defined EACCESS
# define EACCESS EACCES
#endif

#ifndef F_OK
# define F_OK 0
# define X_OK 1
# define W_OK 2
# define R_OK 4
#endif


#ifdef _LIBC

# define access __access
# define getuid __getuid
# define getgid __getgid
# define geteuid __geteuid
# define getegid __getegid
# define group_member __group_member
# define euidaccess __euidaccess
# undef stat
# define stat stat64

#endif

/* Return 0 if the user has permission of type MODE on FILE;
   otherwise, return -1 and set 'errno'.
   Like access, except that it uses the effective user and group
   id's instead of the real ones, and it does not always check for read-only
   file system, text busy, etc.  */

int
euidaccess (const char *file, int mode)
{
#if HAVE_FACCESSAT                   /* glibc, AIX 7, Solaris 11, Cygwin 1.7 */
  return faccessat (AT_FDCWD, file, mode, AT_EACCESS);
#elif defined EFF_ONLY_OK               /* IRIX, OSF/1, Interix */
  return access (file, mode | EFF_ONLY_OK);
#elif defined ACC_SELF                  /* AIX */
  return accessx (file, mode, ACC_SELF);
#elif HAVE_EACCESS                      /* FreeBSD */
  return eaccess (file, mode);
#else       /* Mac OS X, NetBSD, OpenBSD, HP-UX, Solaris, Cygwin, mingw, BeOS */

  uid_t uid = getuid ();
  gid_t gid = getgid ();
  uid_t euid = geteuid ();
  gid_t egid = getegid ();
  struct stat stats;

# if HAVE_DECL_SETREGID && PREFER_NONREENTRANT_EUIDACCESS

  /* Define PREFER_NONREENTRANT_EUIDACCESS if you prefer euidaccess to
     return the correct result even if this would make it
     nonreentrant.  Define this only if your entire application is
     safe even if the uid or gid might temporarily change.  If your
     application uses signal handlers or threads it is probably not
     safe.  */

  if (mode == F_OK)
    return stat (file, &stats);
  else
    {
      int result;
      int saved_errno;

      if (uid != euid)
        setreuid (euid, uid);
      if (gid != egid)
        setregid (egid, gid);

      result = access (file, mode);
      saved_errno = errno;

      /* Restore them.  */
      if (uid != euid)
        setreuid (uid, euid);
      if (gid != egid)
        setregid (gid, egid);

      errno = saved_errno;
      return result;
    }

# else

  /* The following code assumes the traditional Unix model, and is not
     correct on systems that have ACLs or the like.  However, it's
     better than nothing, and it is reentrant.  */

  unsigned int granted;
  if (uid == euid && gid == egid)
    /* If we are not set-uid or set-gid, access does the same.  */
    return access (file, mode);

  if (stat (file, &stats) != 0)
    return -1;

  /* The super-user can read and write any file, and execute any file
     that anyone can execute.  */
  if (euid == ROOT_UID
      && ((mode & X_OK) == 0
          || (stats.st_mode & (S_IXUSR | S_IXGRP | S_IXOTH))))
    return 0;

  /* Convert the mode to traditional form, clearing any bogus bits.  */
  if (R_OK == 4 && W_OK == 2 && X_OK == 1 && F_OK == 0)
    mode &= 7;
  else
    mode = ((mode & R_OK ? 4 : 0)
            + (mode & W_OK ? 2 : 0)
            + (mode & X_OK ? 1 : 0));

  if (mode == 0)
    return 0;                   /* The file exists.  */

  /* Convert the file's permission bits to traditional form.  */
  if (S_IRUSR == (4 << 6) && S_IWUSR == (2 << 6) && S_IXUSR == (1 << 6)
      && S_IRGRP == (4 << 3) && S_IWGRP == (2 << 3) && S_IXGRP == (1 << 3)
      && S_IROTH == (4 << 0) && S_IWOTH == (2 << 0) && S_IXOTH == (1 << 0))
    granted = stats.st_mode;
  else
    granted = ((stats.st_mode & S_IRUSR ? 4 << 6 : 0)
               + (stats.st_mode & S_IWUSR ? 2 << 6 : 0)
               + (stats.st_mode & S_IXUSR ? 1 << 6 : 0)
               + (stats.st_mode & S_IRGRP ? 4 << 3 : 0)
               + (stats.st_mode & S_IWGRP ? 2 << 3 : 0)
               + (stats.st_mode & S_IXGRP ? 1 << 3 : 0)
               + (stats.st_mode & S_IROTH ? 4 << 0 : 0)
               + (stats.st_mode & S_IWOTH ? 2 << 0 : 0)
               + (stats.st_mode & S_IXOTH ? 1 << 0 : 0));

  if (euid == stats.st_uid)
    granted >>= 6;
  else if (egid == stats.st_gid || group_member (stats.st_gid))
    granted >>= 3;

  if ((mode & ~granted) == 0)
    return 0;
  __set_errno (EACCESS);
  return -1;

# endif
#endif
}
#undef euidaccess
#ifdef weak_alias
weak_alias (__euidaccess, euidaccess)
#endif

#ifdef TEST
# include <error.h>
# include <stdio.h>
# include <stdlib.h>

int
main (int argc, char **argv)
{
  char *file;
  int mode;
  int err;

  if (argc < 3)
    abort ();
  file = argv[1];
  mode = atoi (argv[2]);

  err = euidaccess (file, mode);
  printf ("%d\n", err);
  if (err != 0)
    error (0, errno, "%s", file);
  exit (0);
}
#endif
