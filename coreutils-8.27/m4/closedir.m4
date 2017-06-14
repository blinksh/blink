# closedir.m4 serial 5
dnl Copyright (C) 2011-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_CLOSEDIR],
[
  AC_REQUIRE([gl_DIRENT_H_DEFAULTS])

  AC_CHECK_FUNCS([closedir])
  if test $ac_cv_func_closedir = no; then
    HAVE_CLOSEDIR=0
  fi
  dnl Replace closedir() for supporting the gnulib-defined fchdir() function,
  dnl to keep fchdir's bookkeeping up-to-date.
  m4_ifdef([gl_FUNC_FCHDIR], [
    gl_TEST_FCHDIR
    if test $HAVE_FCHDIR = 0; then
      if test $HAVE_CLOSEDIR = 1; then
        REPLACE_CLOSEDIR=1
      fi
    fi
  ])
  dnl Replace closedir() for supporting the gnulib-defined dirfd() function.
  case $host_os,$HAVE_CLOSEDIR in
    os2*,1)
      REPLACE_CLOSEDIR=1;;
  esac
])
