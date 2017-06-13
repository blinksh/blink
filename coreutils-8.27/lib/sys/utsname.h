/* DO NOT EDIT! GENERATED AUTOMATICALLY! */
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

#ifndef _GL_SYS_UTSNAME_H

#if __GNUC__ >= 3
#pragma GCC system_header
#endif


#if 1

/* Minix 3.1.8 has a bug: <stddef.h> must be included before <sys/utsname.h>.
   But avoid namespace pollution on glibc systems.  */
# if defined __minix && !defined __GLIBC__
#  include <stddef.h>
# endif

# include_next <sys/utsname.h>

#endif

#define _GL_SYS_UTSNAME_H

/* The definition of _GL_ARG_NONNULL is copied here.  */
/* _GL_ARG_NONNULL((n,...,m)) tells the compiler and static analyzer tools
   that the values passed as arguments n, ..., m must be non-NULL pointers.
   n = 1 stands for the first argument, n = 2 for the second argument etc.  */
#ifndef _GL_ARG_NONNULL
# if (__GNUC__ == 3 && __GNUC_MINOR__ >= 3) || __GNUC__ > 3
#  define _GL_ARG_NONNULL(params) __attribute__ ((__nonnull__ params))
# else
#  define _GL_ARG_NONNULL(params)
# endif
#endif

/* The definition of _GL_WARN_ON_USE is copied here.  */
#ifndef _GL_WARN_ON_USE

# if 4 < __GNUC__ || (__GNUC__ == 4 && 3 <= __GNUC_MINOR__)
/* A compiler attribute is available in gcc versions 4.3.0 and later.  */
#  define _GL_WARN_ON_USE(function, message) \
extern __typeof__ (function) function __attribute__ ((__warning__ (message)))
# elif __GNUC__ >= 3 && GNULIB_STRICT_CHECKING
/* Verify the existence of the function.  */
#  define _GL_WARN_ON_USE(function, message) \
extern __typeof__ (function) function
# else /* Unsupported.  */
#  define _GL_WARN_ON_USE(function, message) \
_GL_WARN_EXTERN_C int _gl_warn_on_use
# endif
#endif

/* _GL_WARN_ON_USE_CXX (function, rettype, parameters_and_attributes, "string")
   is like _GL_WARN_ON_USE (function, "string"), except that the function is
   declared with the given prototype, consisting of return type, parameters,
   and attributes.
   This variant is useful for overloaded functions in C++. _GL_WARN_ON_USE does
   not work in this case.  */
#ifndef _GL_WARN_ON_USE_CXX
# if 4 < __GNUC__ || (__GNUC__ == 4 && 3 <= __GNUC_MINOR__)
#  define _GL_WARN_ON_USE_CXX(function,rettype,parameters_and_attributes,msg) \
extern rettype function parameters_and_attributes \
     __attribute__ ((__warning__ (msg)))
# elif __GNUC__ >= 3 && GNULIB_STRICT_CHECKING
/* Verify the existence of the function.  */
#  define _GL_WARN_ON_USE_CXX(function,rettype,parameters_and_attributes,msg) \
extern rettype function parameters_and_attributes
# else /* Unsupported.  */
#  define _GL_WARN_ON_USE_CXX(function,rettype,parameters_and_attributes,msg) \
_GL_WARN_EXTERN_C int _gl_warn_on_use
# endif
#endif

/* _GL_WARN_EXTERN_C declaration;
   performs the declaration with C linkage.  */
#ifndef _GL_WARN_EXTERN_C
# if defined __cplusplus
#  define _GL_WARN_EXTERN_C extern "C"
# else
#  define _GL_WARN_EXTERN_C extern
# endif
#endif


#ifdef __cplusplus
extern "C" {
#endif

#if !1
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

#endif /* !1 */


#if 1
# if !1
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


#endif /* _GL_SYS_UTSNAME_H */
