# langinfo_h.m4 serial 7
dnl Copyright (C) 2009-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_LANGINFO_H],
[
  AC_REQUIRE([gl_LANGINFO_H_DEFAULTS])

  dnl Persuade glibc-2.0.6 <langinfo.h> to define CODESET.
  AC_REQUIRE([AC_USE_SYSTEM_EXTENSIONS])

  dnl <langinfo.h> is always overridden, because of GNULIB_POSIXCHECK.
  gl_CHECK_NEXT_HEADERS([langinfo.h])

  dnl Determine whether <langinfo.h> exists. It is missing on mingw and BeOS.
  HAVE_LANGINFO_CODESET=0
  HAVE_LANGINFO_T_FMT_AMPM=0
  HAVE_LANGINFO_ERA=0
  HAVE_LANGINFO_YESEXPR=0
  AC_CHECK_HEADERS_ONCE([langinfo.h])
  if test $ac_cv_header_langinfo_h = yes; then
    HAVE_LANGINFO_H=1
    dnl Determine what <langinfo.h> defines. CODESET and ERA etc. are missing
    dnl on OpenBSD 3.8. T_FMT_AMPM and YESEXPR, NOEXPR are missing on IRIX 5.3.
    AC_CACHE_CHECK([whether langinfo.h defines CODESET],
      [gl_cv_header_langinfo_codeset],
      [AC_COMPILE_IFELSE(
         [AC_LANG_PROGRAM([[#include <langinfo.h>
int a = CODESET;
]])],
         [gl_cv_header_langinfo_codeset=yes],
         [gl_cv_header_langinfo_codeset=no])
      ])
    if test $gl_cv_header_langinfo_codeset = yes; then
      HAVE_LANGINFO_CODESET=1
    fi
    AC_CACHE_CHECK([whether langinfo.h defines T_FMT_AMPM],
      [gl_cv_header_langinfo_t_fmt_ampm],
      [AC_COMPILE_IFELSE(
         [AC_LANG_PROGRAM([[#include <langinfo.h>
int a = T_FMT_AMPM;
]])],
         [gl_cv_header_langinfo_t_fmt_ampm=yes],
         [gl_cv_header_langinfo_t_fmt_ampm=no])
      ])
    if test $gl_cv_header_langinfo_t_fmt_ampm = yes; then
      HAVE_LANGINFO_T_FMT_AMPM=1
    fi
    AC_CACHE_CHECK([whether langinfo.h defines ERA],
      [gl_cv_header_langinfo_era],
      [AC_COMPILE_IFELSE(
         [AC_LANG_PROGRAM([[#include <langinfo.h>
int a = ERA;
]])],
         [gl_cv_header_langinfo_era=yes],
         [gl_cv_header_langinfo_era=no])
      ])
    if test $gl_cv_header_langinfo_era = yes; then
      HAVE_LANGINFO_ERA=1
    fi
    AC_CACHE_CHECK([whether langinfo.h defines YESEXPR],
      [gl_cv_header_langinfo_yesexpr],
      [AC_COMPILE_IFELSE(
         [AC_LANG_PROGRAM([[#include <langinfo.h>
int a = YESEXPR;
]])],
         [gl_cv_header_langinfo_yesexpr=yes],
         [gl_cv_header_langinfo_yesexpr=no])
      ])
    if test $gl_cv_header_langinfo_yesexpr = yes; then
      HAVE_LANGINFO_YESEXPR=1
    fi
  else
    HAVE_LANGINFO_H=0
  fi
  AC_SUBST([HAVE_LANGINFO_H])
  AC_SUBST([HAVE_LANGINFO_CODESET])
  AC_SUBST([HAVE_LANGINFO_T_FMT_AMPM])
  AC_SUBST([HAVE_LANGINFO_ERA])
  AC_SUBST([HAVE_LANGINFO_YESEXPR])

  dnl Check for declarations of anything we want to poison if the
  dnl corresponding gnulib module is not in use.
  gl_WARN_ON_USE_PREPARE([[#include <langinfo.h>
    ]], [nl_langinfo])
])

AC_DEFUN([gl_LANGINFO_MODULE_INDICATOR],
[
  dnl Use AC_REQUIRE here, so that the default settings are expanded once only.
  AC_REQUIRE([gl_LANGINFO_H_DEFAULTS])
  gl_MODULE_INDICATOR_SET_VARIABLE([$1])
  dnl Define it also as a C macro, for the benefit of the unit tests.
  gl_MODULE_INDICATOR_FOR_TESTS([$1])
])

AC_DEFUN([gl_LANGINFO_H_DEFAULTS],
[
  GNULIB_NL_LANGINFO=0;  AC_SUBST([GNULIB_NL_LANGINFO])
  dnl Assume proper GNU behavior unless another module says otherwise.
  HAVE_NL_LANGINFO=1;    AC_SUBST([HAVE_NL_LANGINFO])
  REPLACE_NL_LANGINFO=0; AC_SUBST([REPLACE_NL_LANGINFO])
])
