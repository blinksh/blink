# vprintf-posix.m4 serial 3
dnl Copyright (C) 2007-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_VPRINTF_POSIX],
[
  AC_REQUIRE([gl_FUNC_VFPRINTF_POSIX])
  if test $gl_cv_func_vfprintf_posix = no; then
    gl_REPLACE_VPRINTF
  fi
])

AC_DEFUN([gl_REPLACE_VPRINTF],
[
  AC_REQUIRE([gl_STDIO_H_DEFAULTS])
  AC_LIBOBJ([vprintf])
  REPLACE_VPRINTF=1
  AC_DEFINE([REPLACE_VPRINTF_POSIX], [1],
    [Define if vprintf is overridden by a POSIX compliant gnulib implementation.])
  gl_PREREQ_VPRINTF
])

AC_DEFUN([gl_PREREQ_VPRINTF], [:])
