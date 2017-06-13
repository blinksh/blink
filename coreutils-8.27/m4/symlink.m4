# serial 6
# See if we need to provide symlink replacement.

dnl Copyright (C) 2009-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

# Written by Eric Blake.

AC_DEFUN([gl_FUNC_SYMLINK],
[
  AC_REQUIRE([gl_UNISTD_H_DEFAULTS])
  AC_REQUIRE([AC_CANONICAL_HOST]) dnl for cross-compiles
  AC_CHECK_FUNCS_ONCE([symlink])
  dnl The best we can do on mingw is provide a dummy that always fails, so
  dnl that compilation can proceed with fewer ifdefs.  On FreeBSD 7.2, AIX 7.1,
  dnl and Solaris 9, we want to fix a bug with trailing slash handling.
  if test $ac_cv_func_symlink = no; then
    HAVE_SYMLINK=0
  else
    AC_CACHE_CHECK([whether symlink handles trailing slash correctly],
      [gl_cv_func_symlink_works],
      [AC_RUN_IFELSE(
         [AC_LANG_PROGRAM(
           [[#include <unistd.h>
           ]],
           [[int result = 0;
             if (!symlink ("a", "conftest.link/"))
               result |= 1;
             if (symlink ("conftest.f", "conftest.lnk2"))
               result |= 2;
             else if (!symlink ("a", "conftest.lnk2/"))
               result |= 4;
             return result;
           ]])],
         [gl_cv_func_symlink_works=yes], [gl_cv_func_symlink_works=no],
         [case "$host_os" in
                    # Guess yes on glibc systems.
            *-gnu*) gl_cv_func_symlink_works="guessing yes" ;;
                    # If we don't know, assume the worst.
            *)      gl_cv_func_symlink_works="guessing no" ;;
          esac
         ])
      rm -f conftest.f conftest.link conftest.lnk2])
    case "$gl_cv_func_symlink_works" in
      *yes) ;;
      *)
        REPLACE_SYMLINK=1
        ;;
    esac
  fi
])
