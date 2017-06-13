# rewinddir.m4 serial 1
dnl Copyright (C) 2011-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_REWINDDIR],
[
  AC_REQUIRE([gl_DIRENT_H_DEFAULTS])

  AC_CHECK_FUNCS([rewinddir])
  if test $ac_cv_func_rewinddir = no; then
    HAVE_REWINDDIR=0
  fi
])
