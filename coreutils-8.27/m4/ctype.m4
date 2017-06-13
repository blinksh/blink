# ctype_h.m4 serial 6
dnl Copyright (C) 2009-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_CTYPE_H],
[
  AC_REQUIRE([gl_CTYPE_H_DEFAULTS])

  dnl <ctype.h> is always overridden, because of GNULIB_POSIXCHECK.
  gl_NEXT_HEADERS([ctype.h])

  dnl Check for declarations of anything we want to poison if the
  dnl corresponding gnulib module is not in use.
  gl_WARN_ON_USE_PREPARE([[#include <ctype.h>
    ]], [isblank])
])

AC_DEFUN([gl_CTYPE_MODULE_INDICATOR],
[
  dnl Use AC_REQUIRE here, so that the default settings are expanded once only.
  AC_REQUIRE([gl_CTYPE_H_DEFAULTS])
  gl_MODULE_INDICATOR_SET_VARIABLE([$1])
])

AC_DEFUN([gl_CTYPE_H_DEFAULTS],
[
  GNULIB_ISBLANK=0; AC_SUBST([GNULIB_ISBLANK])
  dnl Assume proper GNU behavior unless another module says otherwise.
  HAVE_ISBLANK=1;   AC_SUBST([HAVE_ISBLANK])
])
