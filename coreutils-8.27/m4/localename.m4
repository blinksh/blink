# localename.m4 serial 2
dnl Copyright (C) 2007, 2009-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_LOCALENAME],
[
  AC_REQUIRE([gt_LC_MESSAGES])
  AC_REQUIRE([gt_INTL_MACOSX])
  AC_CHECK_FUNCS([setlocale uselocale])
  dnl Solaris 12 provides getlocalename_l, while Illumos doesn't have
  dnl it nor the equivalent.
  if test $ac_cv_func_uselocale = yes; then
    AC_CHECK_FUNCS([getlocalename_l])
  fi
])
