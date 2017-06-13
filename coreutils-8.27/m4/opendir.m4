# opendir.m4 serial 4
dnl Copyright (C) 2011-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_OPENDIR],
[
  AC_REQUIRE([gl_DIRENT_H_DEFAULTS])

  AC_CHECK_FUNCS([opendir])
  if test $ac_cv_func_opendir = no; then
    HAVE_OPENDIR=0
  fi
  dnl Replace opendir() for supporting the gnulib-defined fchdir() function,
  dnl to keep fchdir's bookkeeping up-to-date.
  m4_ifdef([gl_FUNC_FCHDIR], [
    gl_TEST_FCHDIR
    if test $HAVE_FCHDIR = 0; then
      if test $HAVE_OPENDIR = 1; then
        REPLACE_OPENDIR=1
      fi
    fi
  ])
  dnl Replace opendir() on OS/2 kLIBC to support dirfd() function replaced
  dnl by gnulib.
  case $host_os,$HAVE_OPENDIR in
    os2*,1)
      REPLACE_OPENDIR=1;;
  esac
])
