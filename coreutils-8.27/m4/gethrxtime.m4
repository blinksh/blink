# gethrxtime.m4 serial 12
dnl Copyright (C) 2005-2006, 2008-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

dnl Written by Paul Eggert.

AC_DEFUN([gl_GETHRXTIME],
[
  AC_REQUIRE([gl_ARITHMETIC_HRTIME_T])
  AC_REQUIRE([gl_USE_SYSTEM_EXTENSIONS])
  AC_REQUIRE([gl_XTIME])
  AC_CHECK_DECLS([gethrtime], [], [], [[#include <time.h>]])
  LIB_GETHRXTIME=
  if test $ac_cv_have_decl_gethrtime = no \
     || test $gl_cv_arithmetic_hrtime_t = no; then
    dnl Find libraries needed to link lib/gethrxtime.c.
    AC_REQUIRE([gl_CLOCK_TIME])
    AC_REQUIRE([gl_USE_SYSTEM_EXTENSIONS])
    AC_CHECK_FUNCS_ONCE([microuptime nanouptime])
    if test $ac_cv_func_nanouptime != yes \
       && { test $ac_cv_have_decl_gethrtime = no \
            || test $gl_cv_arithmetic_hrtime_t = no; }; then
      AC_CACHE_CHECK([whether CLOCK_MONOTONIC or CLOCK_REALTIME is defined],
        [gl_cv_have_clock_gettime_macro],
        [AC_EGREP_CPP([have_clock_gettime_macro],
          [
#          include <time.h>
#          if defined CLOCK_MONOTONIC || defined CLOCK_REALTIME
            have_clock_gettime_macro
#          endif
          ],
          [gl_cv_have_clock_gettime_macro=yes],
          [gl_cv_have_clock_gettime_macro=no])])
      if test $gl_cv_have_clock_gettime_macro = yes; then
        LIB_GETHRXTIME=$LIB_CLOCK_GETTIME
      fi
    fi
  fi
  AC_SUBST([LIB_GETHRXTIME])
])

# Test whether hrtime_t is an arithmetic type.
# It is not arithmetic in older Solaris c89 (which insists on
# not having a long long int type).
AC_DEFUN([gl_ARITHMETIC_HRTIME_T],
[
  AC_REQUIRE([gl_USE_SYSTEM_EXTENSIONS])
  AC_CACHE_CHECK([for arithmetic hrtime_t], [gl_cv_arithmetic_hrtime_t],
    [AC_COMPILE_IFELSE(
       [AC_LANG_PROGRAM([[#include <time.h>]],
          [[hrtime_t x = 0; return x/x;]])],
       [gl_cv_arithmetic_hrtime_t=yes],
       [gl_cv_arithmetic_hrtime_t=no])])
  if test $gl_cv_arithmetic_hrtime_t = yes; then
    AC_DEFINE([HAVE_ARITHMETIC_HRTIME_T], [1],
      [Define if you have an arithmetic hrtime_t type.])
  fi
])

# Prerequisites of lib/xtime.h.
AC_DEFUN([gl_XTIME],
[
  AC_REQUIRE([AC_TYPE_LONG_LONG_INT])
  :
])
