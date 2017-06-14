# serial 11

# Copyright (C) 2001, 2003-2004, 2006, 2008-2017 Free Software Foundation, Inc.
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

# On some systems, mkdir ("foo/", 0700) fails because of the trailing slash.
# On others, mkdir ("foo/./", 0700) mistakenly succeeds.
# On such systems, arrange to use a wrapper function.
AC_DEFUN([gl_FUNC_MKDIR],
[dnl
  AC_REQUIRE([gl_SYS_STAT_H_DEFAULTS])
  AC_REQUIRE([AC_CANONICAL_HOST]) dnl for cross-compiles
  AC_CHECK_HEADERS_ONCE([unistd.h])
  AC_CACHE_CHECK([whether mkdir handles trailing slash],
    [gl_cv_func_mkdir_trailing_slash_works],
    [rm -rf conftest.dir
      AC_RUN_IFELSE([AC_LANG_PROGRAM([[
#       include <sys/types.h>
#       include <sys/stat.h>
]], [return mkdir ("conftest.dir/", 0700);])],
      [gl_cv_func_mkdir_trailing_slash_works=yes],
      [gl_cv_func_mkdir_trailing_slash_works=no],
      [case "$host_os" in
                 # Guess yes on glibc systems.
         *-gnu*) gl_cv_func_mkdir_trailing_slash_works="guessing yes" ;;
                 # If we don't know, assume the worst.
         *)      gl_cv_func_mkdir_trailing_slash_works="guessing no" ;;
       esac
      ])
    rm -rf conftest.dir
    ]
  )
  case "$gl_cv_func_mkdir_trailing_slash_works" in
    *yes) ;;
    *)
      REPLACE_MKDIR=1
      ;;
  esac

  AC_CACHE_CHECK([whether mkdir handles trailing dot],
    [gl_cv_func_mkdir_trailing_dot_works],
    [rm -rf conftest.dir
      AC_RUN_IFELSE([AC_LANG_PROGRAM([[
#       include <sys/types.h>
#       include <sys/stat.h>
]], [return !mkdir ("conftest.dir/./", 0700);])],
      [gl_cv_func_mkdir_trailing_dot_works=yes],
      [gl_cv_func_mkdir_trailing_dot_works=no],
      [case "$host_os" in
                 # Guess yes on glibc systems.
         *-gnu*) gl_cv_func_mkdir_trailing_dot_works="guessing yes" ;;
                 # If we don't know, assume the worst.
         *)      gl_cv_func_mkdir_trailing_dot_works="guessing no" ;;
       esac
      ])
    rm -rf conftest.dir
    ]
  )
  case "$gl_cv_func_mkdir_trailing_dot_works" in
    *yes) ;;
    *)
      REPLACE_MKDIR=1
      AC_DEFINE([FUNC_MKDIR_DOT_BUG], [1], [Define to 1 if mkdir mistakenly
        creates a directory given with a trailing dot component.])
      ;;
  esac
])
