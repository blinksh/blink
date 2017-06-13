# remove.m4 serial 5
dnl Copyright (C) 2009-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_REMOVE],
[
  AC_REQUIRE([AC_CANONICAL_HOST]) dnl for cross-compiles
  AC_REQUIRE([gl_STDIO_H_DEFAULTS])
  AC_REQUIRE([gl_FUNC_RMDIR])
  AC_REQUIRE([gl_FUNC_UNLINK])
  if { case "$gl_cv_func_rmdir_works:$gl_cv_func_unlink_honors_slashes" in
         *yes:*yes) false;;
         *) true;;
       esac
     }; then
    dnl If either underlying syscall is broken, then remove likely has
    dnl the same bug; blindly use our replacement.
    REPLACE_REMOVE=1
  else
    dnl C89 requires remove(), but only POSIX requires it to handle
    dnl directories.  On mingw, directories fails with EPERM.
    AC_CACHE_CHECK([whether remove handles directories],
      [gl_cv_func_remove_dir_works],
      [mkdir conftest.dir
       AC_RUN_IFELSE(
         [AC_LANG_PROGRAM(
           [[#include <stdio.h>
]], [[return remove ("conftest.dir");]])],
         [gl_cv_func_remove_dir_works=yes], [gl_cv_func_remove_dir_works=no],
         [case $host_os in
            mingw*) gl_cv_func_remove_dir_works="guessing no";;
            *) gl_cv_func_remove_dir_works="guessing yes";;
          esac])
       rm -rf conftest.dir])
    case $gl_cv_func_remove_dir_works in
      *no*) REPLACE_REMOVE=1;;
    esac
  fi
])
