# rpmatch.m4 serial 10
dnl Copyright (C) 2002-2003, 2007-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_RPMATCH],
[
  dnl Persuade glibc <stdlib.h> to declare rpmatch().
  AC_REQUIRE([AC_USE_SYSTEM_EXTENSIONS])

  AC_REQUIRE([gl_STDLIB_H_DEFAULTS])
  AC_CHECK_FUNCS([rpmatch])
  if test $ac_cv_func_rpmatch = no; then
    HAVE_RPMATCH=0
  fi
])

# Prerequisites of lib/rpmatch.c.
AC_DEFUN([gl_PREREQ_RPMATCH], [
  AC_CACHE_CHECK([for nl_langinfo and YESEXPR], [gl_cv_langinfo_yesexpr],
    [AC_LINK_IFELSE([AC_LANG_PROGRAM([[#include <langinfo.h>]],
       [[char* cs = nl_langinfo(YESEXPR); return !cs;]])],
       [gl_cv_langinfo_yesexpr=yes],
       [gl_cv_langinfo_yesexpr=no])
    ])
  if test $gl_cv_langinfo_yesexpr = yes; then
    AC_DEFINE([HAVE_LANGINFO_YESEXPR], [1],
      [Define if you have <langinfo.h> and nl_langinfo(YESEXPR).])
  fi
])
