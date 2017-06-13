# termios_h.m4 serial 4
dnl Copyright (C) 2010-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_TERMIOS_H],
[
  dnl Use AC_REQUIRE here, so that the default behavior below is expanded
  dnl once only, before all statements that occur in other macros.
  AC_REQUIRE([gl_TERMIOS_H_DEFAULTS])

  gl_CHECK_NEXT_HEADERS([termios.h])
  if test $ac_cv_header_termios_h != yes; then
    HAVE_TERMIOS_H=0
  fi

  dnl Ensure the type pid_t gets defined.
  AC_REQUIRE([AC_TYPE_PID_T])

  dnl Check for declarations of anything we want to poison if the
  dnl corresponding gnulib module is not in use, and which is not
  dnl guaranteed by C89.
  gl_WARN_ON_USE_PREPARE([[#include <termios.h>]],
    [tcgetsid])
])

AC_DEFUN([gl_TERMIOS_MODULE_INDICATOR],
[
  dnl Use AC_REQUIRE here, so that the default settings are expanded once only.
  AC_REQUIRE([gl_TERMIOS_H_DEFAULTS])
  gl_MODULE_INDICATOR_SET_VARIABLE([$1])
  dnl Define it also as a C macro, for the benefit of the unit tests.
  gl_MODULE_INDICATOR_FOR_TESTS([$1])
])

AC_DEFUN([gl_TERMIOS_H_DEFAULTS],
[
  GNULIB_TCGETSID=0;      AC_SUBST([GNULIB_TCGETSID])
  dnl Assume proper GNU behavior unless another module says otherwise.
  HAVE_DECL_TCGETSID=1;   AC_SUBST([HAVE_DECL_TCGETSID])
  HAVE_TERMIOS_H=1;       AC_SUBST([HAVE_TERMIOS_H])
])
