# iconv_h.m4 serial 8
dnl Copyright (C) 2007-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_ICONV_H],
[
  AC_REQUIRE([gl_ICONV_H_DEFAULTS])

  dnl Execute this unconditionally, because ICONV_H may be set by other
  dnl modules, after this code is executed.
  gl_CHECK_NEXT_HEADERS([iconv.h])
])

dnl Unconditionally enables the replacement of <iconv.h>.
AC_DEFUN([gl_REPLACE_ICONV_H],
[
  AC_REQUIRE([gl_ICONV_H_DEFAULTS])
  ICONV_H='iconv.h'
  AM_CONDITIONAL([GL_GENERATE_ICONV_H], [test -n "$ICONV_H"])
])

AC_DEFUN([gl_ICONV_MODULE_INDICATOR],
[
  dnl Use AC_REQUIRE here, so that the default settings are expanded once only.
  AC_REQUIRE([gl_ICONV_H_DEFAULTS])
  gl_MODULE_INDICATOR_SET_VARIABLE([$1])
])

AC_DEFUN([gl_ICONV_H_DEFAULTS],
[
  GNULIB_ICONV=0;       AC_SUBST([GNULIB_ICONV])
  dnl Assume proper GNU behavior unless another module says otherwise.
  ICONV_CONST=;         AC_SUBST([ICONV_CONST])
  REPLACE_ICONV=0;      AC_SUBST([REPLACE_ICONV])
  REPLACE_ICONV_OPEN=0; AC_SUBST([REPLACE_ICONV_OPEN])
  REPLACE_ICONV_UTF=0;  AC_SUBST([REPLACE_ICONV_UTF])
  ICONV_H='';           AC_SUBST([ICONV_H])
  AM_CONDITIONAL([GL_GENERATE_ICONV_H], [test -n "$ICONV_H"])
])
