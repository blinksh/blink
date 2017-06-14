# getlogin.m4 serial 5
dnl Copyright (C) 2010-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_GETLOGIN],
[
  AC_REQUIRE([gl_UNISTD_H_DEFAULTS])
  AC_CHECK_DECLS_ONCE([getlogin])
  if test $ac_cv_have_decl_getlogin = no; then
    HAVE_DECL_GETLOGIN=0
  fi
  AC_CHECK_FUNCS_ONCE([getlogin])
  if test $ac_cv_func_getlogin = no; then
    HAVE_GETLOGIN=0
  fi
])

dnl Determines the library needed by the implementation of the
dnl getlogin and getlogin_r functions.
AC_DEFUN([gl_LIB_GETLOGIN],
[
  AC_REQUIRE([AC_CANONICAL_HOST])
  case $host_os in
    mingw*)
      LIB_GETLOGIN='-ladvapi32' ;;
    *)
      LIB_GETLOGIN= ;;
  esac
  AC_SUBST([LIB_GETLOGIN])
])
