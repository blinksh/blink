# yield.m4 serial 2
dnl Copyright (C) 2005-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_YIELD],
[
  AC_REQUIRE([gl_THREADLIB])
  dnl On some systems, sched_yield is in librt, rather than in libpthread.
  YIELD_LIB=
  if test $gl_threads_api = posix; then
    dnl Solaris has sched_yield in librt, not in libpthread or libc.
    AC_CHECK_LIB([rt], [sched_yield], [YIELD_LIB=-lrt],
      [dnl Solaris 2.5.1, 2.6 has sched_yield in libposix4, not librt.
       AC_CHECK_LIB([posix4], [sched_yield], [YIELD_LIB=-lposix4])])
  fi
  AC_SUBST([YIELD_LIB])
])
