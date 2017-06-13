# ungetc.m4 serial 3
dnl Copyright (C) 2009-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN_ONCE([gl_FUNC_UNGETC_WORKS],
[
  AC_REQUIRE([AC_PROG_CC])
  AC_REQUIRE([AC_CANONICAL_HOST]) dnl for cross-compiles

  AC_CACHE_CHECK([whether ungetc works on arbitrary bytes],
    [gl_cv_func_ungetc_works],
    [AC_RUN_IFELSE([AC_LANG_PROGRAM([[
#include <stdio.h>
      ]], [FILE *f;
           if (!(f = fopen ("conftest.tmp", "w+"))) return 1;
           if (fputs ("abc", f) < 0) return 2;
           rewind (f);
           if (fgetc (f) != 'a') return 3;
           if (fgetc (f) != 'b') return 4;
           if (ungetc ('d', f) != 'd') return 5;
           if (ftell (f) != 1) return 6;
           if (fgetc (f) != 'd') return 7;
           if (ftell (f) != 2) return 8;
           if (fseek (f, 0, SEEK_CUR) != 0) return 9;
           if (ftell (f) != 2) return 10;
           if (fgetc (f) != 'c') return 11;
           fclose (f); remove ("conftest.tmp");])],
        [gl_cv_func_ungetc_works=yes], [gl_cv_func_ungetc_works=no],
        [case "$host_os" in
                   # Guess yes on glibc and bionic systems.
           *-gnu*|*-android*)
                   gl_cv_func_ungetc_works="guessing yes" ;;
                   # If we don't know, assume the worst.
           *)      gl_cv_func_ungetc_works="guessing no" ;;
         esac
        ])
    ])
  case "$gl_cv_func_ungetc_works" in
    *yes) ;;
    *)
      AC_DEFINE([FUNC_UNGETC_BROKEN], [1],
        [Define to 1 if ungetc is broken when used on arbitrary bytes.])
      ;;
  esac
])
