/* Substitute for <sys/utsname.h>.
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

#ifndef _@GUARD_PREFIX@_SYS_UTSNAME_H

#if __GNUC__ >= 3
@PRAGMA_SYSTEM_HEADER@
#endif
@PRAGMA_COLUMNS@

#if @HAVE_SYS_UTSNAME_H@

/* Minix 3.1.8 has a bug: <stddef.h> must be included before <sys/utsname.h>.
   But avoid namespace pollution on glibc systems.  */
# if defined __minix && !defined __GLIBC__
#  include <stddef.h>
# endif

# @INCLUDE_NEXT@ @NEXT_SYS_UTSNAME_H@

#endif

#define _@GUARD_PREFIX@_SYS_UTSNAME_H

/* The definition of _GL_ARG_NONNULL is copied here.  */

/* The definition of _GL_WARN_ON_USE is copied here.  */


#ifdef __cplusplus
extern "C" {
#endif

#if !@HAVE_STRUCT_UTSNAME@
/* Length of the entries in 'struct utsname' is 256.  */
# define _UTSNAME_LENGTH 256

# ifndef _UTSNAME_NODENAME_LENGTH
#  define _UTSNAME_NODENAME_LENGTH _UTSNAME_LENGTH
# endif
# ifndef _UTSNAME_SYSNAME_LENGTH
#  define _UTSNAME_SYSNAME_LENGTH _UTSNAME_LENGTH
# endif
# ifndef _UTSNAME_RELEASE_LENGTH
#  define _UTSNAME_RELEASE_LENGTH _UTSNAME_LENGTH
# endif
# ifndef _UTSNAME_VERSION_LENGTH
#  define _UTSNAME_VERSION_LENGTH _UTSNAME_LENGTH
# endif
# ifndef _UTSNAME_MACHINE_LENGTH
#  define _UTSNAME_MACHINE_LENGTH _UTSNAME_LENGTH
# endif

# if !GNULIB_defined_struct_utsname
/* Structure describing the system and machine.  */
struct utsname
  {
    /* Name of this node on the network.  */
    char nodename[_UTSNAME_NODENAME_LENGTH];

    /* Name of the implementation of the operating system.  */
    char sysname[_UTSNAME_SYSNAME_LENGTH];
    /* Current release level of this implementation.  */
    char release[_UTSNAME_RELEASE_LENGTH];
    /* Current version level of this release.  */
    char version[_UTSNAME_VERSION_LENGTH];

    /* Name of the hardware type the system is running on.  */
    char machine[_UTSNAME_MACHINE_LENGTH];
  };
#  define GNULIB_defined_struct_utsname 1
# endif

#endif /* !@HAVE_STRUCT_UTSNAME@ */


#if @GNULIB_UNAME@
# if !@HAVE_UNAME@
extern int uname (struct utsname *buf) _GL_ARG_NONNULL ((1));
# endif
#elif defined GNULIB_POSIXCHECK
# undef uname
# if HAVE_RAW_DECL_UNAME
_GL_WARN_ON_USE (uname, "uname is unportable - "
                 "use gnulib module uname for portability");
# endif
#endif


#ifdef __cplusplus
}
#endif


#endif /* _@GUARD_PREFIX@_SYS_UTSNAME_H */
