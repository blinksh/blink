# serial 8

# Copyright (C) 1996, 1999-2001, 2004, 2009-2017 Free Software Foundation, Inc.
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

AC_PREREQ([2.13])

AC_DEFUN([gl_SYS_PROC_UPTIME],
[ dnl Require AC_PROG_CC to see if we're cross compiling.
  AC_REQUIRE([AC_PROG_CC])
  AC_CACHE_CHECK([for /proc/uptime], [gl_cv_have_proc_uptime],
  [gl_cv_have_proc_uptime=no
    test -f /proc/uptime \
      && test "$cross_compiling" = no \
      && cat < /proc/uptime >/dev/null 2>/dev/null \
      && gl_cv_have_proc_uptime=yes])
  if test $gl_cv_have_proc_uptime = yes; then
    AC_DEFINE([HAVE_PROC_UPTIME], [1],
              [  Define if your system has the /proc/uptime special file.])
  fi
])
