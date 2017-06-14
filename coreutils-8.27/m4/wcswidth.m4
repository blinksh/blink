# wcswidth.m4 serial 2
dnl Copyright (C) 2011-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_WCSWIDTH],
[
  AC_REQUIRE([gl_WCHAR_H_DEFAULTS])
  AC_REQUIRE([gl_FUNC_WCWIDTH])
  AC_CHECK_FUNCS_ONCE([wcswidth])
  if test $ac_cv_func_wcswidth = no; then
    HAVE_WCSWIDTH=0
  else
    if test $REPLACE_WCWIDTH = 1; then
      dnl If wcwidth needed to be replaced, wcswidth needs to be replaced
      dnl as well.
      REPLACE_WCSWIDTH=1
    fi
  fi
])
