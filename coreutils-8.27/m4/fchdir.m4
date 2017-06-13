# fchdir.m4 serial 21
dnl Copyright (C) 2006-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_FCHDIR],
[
  AC_REQUIRE([gl_UNISTD_H_DEFAULTS])
  AC_REQUIRE([gl_DIRENT_H_DEFAULTS])
  AC_REQUIRE([AC_CANONICAL_HOST]) dnl for cross-compiles

  AC_CHECK_DECLS_ONCE([fchdir])
  if test $ac_cv_have_decl_fchdir = no; then
    HAVE_DECL_FCHDIR=0
  fi

  AC_REQUIRE([gl_TEST_FCHDIR])
  if test $HAVE_FCHDIR = 0; then
    AC_LIBOBJ([fchdir])
    gl_PREREQ_FCHDIR
    AC_DEFINE([REPLACE_FCHDIR], [1],
      [Define to 1 if gnulib's fchdir() replacement is used.])
    dnl We must also replace anything that can manipulate a directory fd,
    dnl to keep our bookkeeping up-to-date.  We don't have to replace
    dnl fstatat, since no platform has fstatat but lacks fchdir.
    AC_CACHE_CHECK([whether open can visit directories],
      [gl_cv_func_open_directory_works],
      [AC_RUN_IFELSE([AC_LANG_PROGRAM([[#include <fcntl.h>
]], [return open(".", O_RDONLY) < 0;])],
        [gl_cv_func_open_directory_works=yes],
        [gl_cv_func_open_directory_works=no],
        [case "$host_os" in
                   # Guess yes on glibc systems.
           *-gnu*) gl_cv_func_open_directory_works="guessing yes" ;;
                   # If we don't know, assume the worst.
           *)      gl_cv_func_open_directory_works="guessing no" ;;
         esac
        ])])
    case "$gl_cv_func_open_directory_works" in
      *yes) ;;
      *)
        AC_DEFINE([REPLACE_OPEN_DIRECTORY], [1], [Define to 1 if open() should
work around the inability to open a directory.])
        ;;
    esac
  fi
])

# Determine whether to use the overrides in lib/fchdir.c.
AC_DEFUN([gl_TEST_FCHDIR],
[
  AC_REQUIRE([gl_UNISTD_H_DEFAULTS])
  AC_CHECK_FUNCS_ONCE([fchdir])
  if test $ac_cv_func_fchdir = no; then
    HAVE_FCHDIR=0
  fi
])

# Prerequisites of lib/fchdir.c.
AC_DEFUN([gl_PREREQ_FCHDIR], [:])
