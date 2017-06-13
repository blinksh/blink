# sys_select_h.m4 serial 20
dnl Copyright (C) 2006-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_HEADER_SYS_SELECT],
[
  AC_REQUIRE([AC_C_RESTRICT])
  AC_REQUIRE([gl_SYS_SELECT_H_DEFAULTS])
  AC_CACHE_CHECK([whether <sys/select.h> is self-contained],
    [gl_cv_header_sys_select_h_selfcontained],
    [
      dnl Test against two bugs:
      dnl 1. On many platforms, <sys/select.h> assumes prior inclusion of
      dnl    <sys/types.h>.
      dnl 2. On OSF/1 4.0, <sys/select.h> provides only a forward declaration
      dnl    of 'struct timeval', and no definition of this type.
      AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[#include <sys/select.h>]],
                                         [[struct timeval b;]])],
        [gl_cv_header_sys_select_h_selfcontained=yes],
        [gl_cv_header_sys_select_h_selfcontained=no])
      dnl Test against another bug:
      dnl 3. On Solaris 10, <sys/select.h> provides an FD_ZERO implementation
      dnl    that relies on memset(), but without including <string.h>.
      if test $gl_cv_header_sys_select_h_selfcontained = yes; then
        AC_COMPILE_IFELSE(
          [AC_LANG_PROGRAM([[#include <sys/select.h>]],
                           [[int memset; int bzero;]])
          ],
          [AC_LINK_IFELSE(
             [AC_LANG_PROGRAM([[#include <sys/select.h>]], [[
                  #undef memset
                  #define memset nonexistent_memset
                  extern
                  #ifdef __cplusplus
                  "C"
                  #endif
                  void *memset (void *, int, unsigned long);
                  #undef bzero
                  #define bzero nonexistent_bzero
                  extern
                  #ifdef __cplusplus
                  "C"
                  #endif
                  void bzero (void *, unsigned long);
                  fd_set fds;
                  FD_ZERO (&fds);
                ]])
             ],
             [],
             [gl_cv_header_sys_select_h_selfcontained=no])
          ])
      fi
    ])
  dnl <sys/select.h> is always overridden, because of GNULIB_POSIXCHECK.
  gl_CHECK_NEXT_HEADERS([sys/select.h])
  if test $ac_cv_header_sys_select_h = yes; then
    HAVE_SYS_SELECT_H=1
  else
    HAVE_SYS_SELECT_H=0
  fi
  AC_SUBST([HAVE_SYS_SELECT_H])
  gl_PREREQ_SYS_H_WINSOCK2

  dnl Check for declarations of anything we want to poison if the
  dnl corresponding gnulib module is not in use.
  gl_WARN_ON_USE_PREPARE([[
/* Some systems require prerequisite headers.  */
#include <sys/types.h>
#if !(defined __GLIBC__ && !defined __UCLIBC__) && HAVE_SYS_TIME_H
# include <sys/time.h>
#endif
#include <sys/select.h>
    ]], [pselect select])
])

AC_DEFUN([gl_SYS_SELECT_MODULE_INDICATOR],
[
  dnl Use AC_REQUIRE here, so that the default settings are expanded once only.
  AC_REQUIRE([gl_SYS_SELECT_H_DEFAULTS])
  gl_MODULE_INDICATOR_SET_VARIABLE([$1])
  dnl Define it also as a C macro, for the benefit of the unit tests.
  gl_MODULE_INDICATOR_FOR_TESTS([$1])
])

AC_DEFUN([gl_SYS_SELECT_H_DEFAULTS],
[
  GNULIB_PSELECT=0; AC_SUBST([GNULIB_PSELECT])
  GNULIB_SELECT=0; AC_SUBST([GNULIB_SELECT])
  dnl Assume proper GNU behavior unless another module says otherwise.
  HAVE_PSELECT=1; AC_SUBST([HAVE_PSELECT])
  REPLACE_PSELECT=0; AC_SUBST([REPLACE_PSELECT])
  REPLACE_SELECT=0; AC_SUBST([REPLACE_SELECT])
])
