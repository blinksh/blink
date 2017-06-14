# getpass.m4 serial 14
dnl Copyright (C) 2002-2003, 2005-2006, 2009-2017 Free Software Foundation,
dnl Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

# Provide a getpass() function if the system doesn't have it.
AC_DEFUN([gl_FUNC_GETPASS],
[
  dnl Persuade Solaris <unistd.h> and <stdlib.h> to declare getpass().
  AC_REQUIRE([gl_USE_SYSTEM_EXTENSIONS])

  AC_CHECK_FUNCS([getpass])
  AC_CHECK_DECLS_ONCE([getpass])
  if test $ac_cv_func_getpass = yes; then
    HAVE_GETPASS=1
  else
    HAVE_GETPASS=0
  fi
])

# Provide the GNU getpass() implementation. It supports passwords of
# arbitrary length (not just 8 bytes as on HP-UX).
AC_DEFUN([gl_FUNC_GETPASS_GNU],
[
  dnl Persuade Solaris <unistd.h> and <stdlib.h> to declare getpass().
  AC_REQUIRE([gl_USE_SYSTEM_EXTENSIONS])

  AC_CHECK_DECLS_ONCE([getpass])
  dnl TODO: Detect when GNU getpass() is already found in glibc.
  REPLACE_GETPASS=1

  if test $REPLACE_GETPASS = 1; then
    dnl We must choose a different name for our function, since on ELF systems
    dnl an unusable getpass() in libc.so would override our getpass() if it is
    dnl compiled into a shared library.
    AC_DEFINE([getpass], [gnu_getpass],
      [Define to a replacement function name for getpass().])
  fi
])

# Prerequisites of lib/getpass.c.
AC_DEFUN([gl_PREREQ_GETPASS], [
  AC_CHECK_HEADERS_ONCE([stdio_ext.h termios.h])
  AC_CHECK_FUNCS_ONCE([__fsetlocking tcgetattr tcsetattr])
  AC_CHECK_DECLS([__fsetlocking],,,
    [[#include <stdio.h>
      #if HAVE_STDIO_EXT_H
       #include <stdio_ext.h>
      #endif]])
  AC_CHECK_DECLS_ONCE([fflush_unlocked])
  AC_CHECK_DECLS_ONCE([flockfile])
  AC_CHECK_DECLS_ONCE([fputs_unlocked])
  AC_CHECK_DECLS_ONCE([funlockfile])
  AC_CHECK_DECLS_ONCE([putc_unlocked])
  :
])
