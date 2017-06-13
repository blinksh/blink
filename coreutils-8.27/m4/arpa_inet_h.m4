# arpa_inet_h.m4 serial 13
dnl Copyright (C) 2006, 2008-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

dnl Written by Simon Josefsson and Bruno Haible

AC_DEFUN([gl_HEADER_ARPA_INET],
[
  dnl Use AC_REQUIRE here, so that the default behavior below is expanded
  dnl once only, before all statements that occur in other macros.
  AC_REQUIRE([gl_ARPA_INET_H_DEFAULTS])

  AC_CHECK_HEADERS_ONCE([arpa/inet.h])
  if test $ac_cv_header_arpa_inet_h = yes; then
    HAVE_ARPA_INET_H=1
  else
    HAVE_ARPA_INET_H=0
  fi
  AC_SUBST([HAVE_ARPA_INET_H])
  dnl <arpa/inet.h> is always overridden, because of GNULIB_POSIXCHECK.
  gl_CHECK_NEXT_HEADERS([arpa/inet.h])

  AC_REQUIRE([gl_FEATURES_H])

  dnl Check for declarations of anything we want to poison if the
  dnl corresponding gnulib module is not in use.
  gl_WARN_ON_USE_PREPARE([[
/* On some systems, this header is not self-consistent.  */
#if !(defined __GLIBC__ || defined __UCLIBC__)
# include <sys/socket.h>
#endif
#ifdef __TANDEM
# include <netdb.h>
#endif
#include <arpa/inet.h>
    ]], [inet_ntop inet_pton])
])

AC_DEFUN([gl_ARPA_INET_MODULE_INDICATOR],
[
  dnl Use AC_REQUIRE here, so that the default settings are expanded once only.
  AC_REQUIRE([gl_ARPA_INET_H_DEFAULTS])
  gl_MODULE_INDICATOR_SET_VARIABLE([$1])
])

AC_DEFUN([gl_ARPA_INET_H_DEFAULTS],
[
  GNULIB_INET_NTOP=0;     AC_SUBST([GNULIB_INET_NTOP])
  GNULIB_INET_PTON=0;     AC_SUBST([GNULIB_INET_PTON])
  dnl Assume proper GNU behavior unless another module says otherwise.
  HAVE_DECL_INET_NTOP=1;  AC_SUBST([HAVE_DECL_INET_NTOP])
  HAVE_DECL_INET_PTON=1;  AC_SUBST([HAVE_DECL_INET_PTON])
  REPLACE_INET_NTOP=0;    AC_SUBST([REPLACE_INET_NTOP])
  REPLACE_INET_PTON=0;    AC_SUBST([REPLACE_INET_PTON])
])
