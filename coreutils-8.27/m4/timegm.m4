# timegm.m4 serial 11
dnl Copyright (C) 2003, 2007, 2009-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_TIMEGM],
[
  AC_REQUIRE([gl_HEADER_TIME_H_DEFAULTS])
  AC_REQUIRE([gl_FUNC_MKTIME])
  REPLACE_TIMEGM=0
  AC_CHECK_FUNCS_ONCE([timegm])
  if test $ac_cv_func_timegm = yes; then
    if test $gl_cv_func_working_mktime = no; then
      # Assume that timegm is buggy if mktime is.
      REPLACE_TIMEGM=1
    fi
  else
    HAVE_TIMEGM=0
  fi
])

# Prerequisites of lib/timegm.c.
AC_DEFUN([gl_PREREQ_TIMEGM], [
  :
])
