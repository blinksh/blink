# fchmodat.m4 serial 1
dnl Copyright (C) 2004-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

# Written by Jim Meyering.

AC_DEFUN([gl_FUNC_FCHMODAT],
[
  AC_REQUIRE([gl_SYS_STAT_H_DEFAULTS])
  AC_REQUIRE([gl_USE_SYSTEM_EXTENSIONS])
  AC_CHECK_FUNCS_ONCE([fchmodat lchmod])
  if test $ac_cv_func_fchmodat != yes; then
    HAVE_FCHMODAT=0
  fi
])
