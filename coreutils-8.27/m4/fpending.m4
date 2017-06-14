# serial 22

# Copyright (C) 2000-2001, 2004-2017 Free Software Foundation, Inc.
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

dnl From Jim Meyering
dnl Using code from emacs, based on suggestions from Paul Eggert
dnl and Ulrich Drepper.

dnl Find out how to determine the number of pending output bytes on a stream.
dnl glibc (2.1.93 and newer) and Solaris provide __fpending.  On other systems,
dnl we have to grub around in the (possibly opaque) FILE struct.

AC_DEFUN([gl_FUNC_FPENDING],
[
  AC_CHECK_HEADERS_ONCE([stdio_ext.h])
  fp_headers='
    #include <stdio.h>
    #if HAVE_STDIO_EXT_H
    # include <stdio_ext.h>
    #endif
  '
  AC_CACHE_CHECK([for __fpending], [gl_cv_func___fpending],
    [
      AC_LINK_IFELSE(
        [AC_LANG_PROGRAM([$fp_headers],
           [[return ! __fpending (stdin);]])],
        [gl_cv_func___fpending=yes],
        [gl_cv_func___fpending=no])
    ])
  if test $gl_cv_func___fpending = yes; then
    AC_CHECK_DECLS([__fpending], [], [], [$fp_headers])
  fi
])
