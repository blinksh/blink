# sys_uio_h.m4 serial 1
dnl Copyright (C) 2011-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_HEADER_SYS_UIO],
[
  AC_REQUIRE([gl_SYS_UIO_H_DEFAULTS])
  dnl <sys/uio.h> is always overridden, because of GNULIB_POSIXCHECK.
  gl_CHECK_NEXT_HEADERS([sys/uio.h])
  if test $ac_cv_header_sys_uio_h = yes; then
    HAVE_SYS_UIO_H=1
  else
    HAVE_SYS_UIO_H=0
  fi
  AC_SUBST([HAVE_SYS_UIO_H])
])

AC_DEFUN([gl_SYS_UIO_MODULE_INDICATOR],
[
  dnl Use AC_REQUIRE here, so that the default settings are expanded once only.
  AC_REQUIRE([gl_SYS_UIO_H_DEFAULTS])
  gl_MODULE_INDICATOR_SET_VARIABLE([$1])
  dnl Define it also as a C macro, for the benefit of the unit tests.
  gl_MODULE_INDICATOR_FOR_TESTS([$1])
])

AC_DEFUN([gl_SYS_UIO_H_DEFAULTS],
[
])
