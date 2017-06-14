# serial 5
# See if we need to provide mknod replacement.

dnl Copyright (C) 2009-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

# Written by Eric Blake.

AC_DEFUN([gl_FUNC_MKNOD],
[
  AC_REQUIRE([gl_SYS_STAT_H_DEFAULTS])
  AC_REQUIRE([AC_CANONICAL_HOST]) dnl for cross-compiles
  AC_REQUIRE([gl_FUNC_MKFIFO])
  AC_REQUIRE([gl_USE_SYSTEM_EXTENSIONS])
  AC_CHECK_FUNCS_ONCE([mknod])
  if test $ac_cv_func_mknod = no; then
    HAVE_MKNOD=0
  else
    dnl Detect BSD bug, where mknod requires root privileges to create fifo.
    AC_CACHE_CHECK([whether mknod can create fifo without root privileges],
      [gl_cv_func_mknod_works],
      [AC_RUN_IFELSE(
         [AC_LANG_PROGRAM(
           [[#include <sys/stat.h>
             #include <unistd.h>

             /* Copied from root-uid.h.  FIXME: Just use root-uid.h.  */
             #ifdef __TANDEM
             # define ROOT_UID 65535
             #else
             # define ROOT_UID 0
             #endif
]], [[/* Indeterminate for super-user, assume no.  Why are you running
         configure as root, anyway?  */
      if (geteuid () == ROOT_UID) return 99;
      if (mknod ("conftest.fifo", S_IFIFO | 0600, 0)) return 2;]])],
         [gl_cv_func_mknod_works=yes],
         [if test $? = 99 && test x"$FORCE_UNSAFE_CONFIGURE" = x; then
            AC_MSG_FAILURE([you should not run configure as root ]dnl
[(set FORCE_UNSAFE_CONFIGURE=1 in environment to bypass this check)])
          fi
          gl_cv_func_mknod_works=no],
         [case "$host_os" in
                    # Guess yes on glibc systems.
            *-gnu*) gl_cv_func_mknod_works="guessing yes" ;;
                    # If we don't know, assume the worst.
            *)      gl_cv_func_mknod_works="guessing no" ;;
          esac
         ])
       rm -f conftest.fifo])
    case "$gl_cv_func_mknod_works" in
      *yes) ;;
      *)
        REPLACE_MKNOD=1
        AC_DEFINE([MKNOD_FIFO_BUG], [1], [Define to 1 if mknod cannot create
          a fifo without super-user privileges])
        ;;
    esac
    dnl Systems that mishandle trailing slash on mkfifo also goof on mknod.
    if test $REPLACE_MKFIFO = 1; then
      REPLACE_MKNOD=1
    fi
  fi
])
