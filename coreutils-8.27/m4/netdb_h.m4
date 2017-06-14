# netdb_h.m4 serial 11
dnl Copyright (C) 2008-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_HEADER_NETDB],
[
  AC_REQUIRE([gl_NETDB_H_DEFAULTS])
  gl_CHECK_NEXT_HEADERS([netdb.h])
  if test $ac_cv_header_netdb_h = yes; then
    HAVE_NETDB_H=1
  else
    HAVE_NETDB_H=0
  fi
  AC_SUBST([HAVE_NETDB_H])

  dnl Check for declarations of anything we want to poison if the
  dnl corresponding gnulib module is not in use.
  gl_WARN_ON_USE_PREPARE([[#include <netdb.h>]],
    [getaddrinfo freeaddrinfo gai_strerror getnameinfo])
])

AC_DEFUN([gl_NETDB_MODULE_INDICATOR],
[
  dnl Use AC_REQUIRE here, so that the default settings are expanded once only.
  AC_REQUIRE([gl_NETDB_H_DEFAULTS])
  gl_MODULE_INDICATOR_SET_VARIABLE([$1])
  dnl Define it also as a C macro, for the benefit of the unit tests.
  gl_MODULE_INDICATOR_FOR_TESTS([$1])
])

AC_DEFUN([gl_NETDB_H_DEFAULTS],
[
  GNULIB_GETADDRINFO=0; AC_SUBST([GNULIB_GETADDRINFO])
  dnl Assume proper GNU behavior unless another module says otherwise.
  HAVE_STRUCT_ADDRINFO=1;   AC_SUBST([HAVE_STRUCT_ADDRINFO])
  HAVE_DECL_FREEADDRINFO=1; AC_SUBST([HAVE_DECL_FREEADDRINFO])
  HAVE_DECL_GAI_STRERROR=1; AC_SUBST([HAVE_DECL_GAI_STRERROR])
  HAVE_DECL_GETADDRINFO=1;  AC_SUBST([HAVE_DECL_GETADDRINFO])
  HAVE_DECL_GETNAMEINFO=1;  AC_SUBST([HAVE_DECL_GETNAMEINFO])
  REPLACE_GAI_STRERROR=0;   AC_SUBST([REPLACE_GAI_STRERROR])
])
