# serial 26

# Copyright (C) 2001, 2003, 2005-2006, 2009-2017 Free Software Foundation, Inc.
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

dnl From Volker Borchert.
dnl Determine whether rename works for source file names with a trailing slash.
dnl The rename from SunOS 4.1.1_U1 doesn't.
dnl
dnl If it doesn't, then define RENAME_TRAILING_SLASH_BUG and arrange
dnl to compile the wrapper function.
dnl

AC_DEFUN([gl_FUNC_RENAME],
[
  AC_REQUIRE([AC_CANONICAL_HOST])
  AC_REQUIRE([gl_STDIO_H_DEFAULTS])
  AC_CHECK_FUNCS_ONCE([lstat])

  dnl Solaris 10, AIX 7.1 mistakenly allow rename("file","name/").
  dnl NetBSD 1.6 mistakenly forbids rename("dir","name/").
  dnl FreeBSD 7.2 mistakenly allows rename("file","link-to-file/").
  dnl The Solaris bug can be worked around without stripping
  dnl trailing slash, while the NetBSD bug requires stripping;
  dnl the two conditions can be distinguished by whether hard
  dnl links are also broken.
  AC_CACHE_CHECK([whether rename honors trailing slash on destination],
    [gl_cv_func_rename_slash_dst_works],
    [rm -rf conftest.f conftest.f1 conftest.f2 conftest.d1 conftest.d2 conftest.lnk
    touch conftest.f && touch conftest.f1 && mkdir conftest.d1 ||
      AC_MSG_ERROR([cannot create temporary files])
    # Assume that if we have lstat, we can also check symlinks.
    if test $ac_cv_func_lstat = yes; then
      ln -s conftest.f conftest.lnk
    fi
    AC_RUN_IFELSE(
      [AC_LANG_PROGRAM([[
#        include <stdio.h>
#        include <stdlib.h>
         ]],
         [[int result = 0;
           if (rename ("conftest.f1", "conftest.f2/") == 0)
             result |= 1;
           if (rename ("conftest.d1", "conftest.d2/") != 0)
             result |= 2;
#if HAVE_LSTAT
           if (rename ("conftest.f", "conftest.lnk/") == 0)
             result |= 4;
#endif
           return result;
         ]])],
      [gl_cv_func_rename_slash_dst_works=yes],
      [gl_cv_func_rename_slash_dst_works=no],
      dnl When crosscompiling, assume rename is broken.
      [case "$host_os" in
                 # Guess yes on glibc systems.
         *-gnu*) gl_cv_func_rename_slash_dst_works="guessing yes" ;;
                 # If we don't know, assume the worst.
         *)      gl_cv_func_rename_slash_dst_works="guessing no" ;;
       esac
      ])
    rm -rf conftest.f conftest.f1 conftest.f2 conftest.d1 conftest.d2 conftest.lnk
  ])
  case "$gl_cv_func_rename_slash_dst_works" in
    *yes) ;;
    *)
      REPLACE_RENAME=1
      AC_DEFINE([RENAME_TRAILING_SLASH_DEST_BUG], [1],
        [Define if rename does not correctly handle slashes on the destination
         argument, such as on Solaris 10 or NetBSD 1.6.])
      ;;
  esac

  dnl SunOS 4.1.1_U1 mistakenly forbids rename("dir/","name").
  dnl Solaris 9 mistakenly allows rename("file/","name").
  dnl FreeBSD 7.2 mistakenly allows rename("link-to-file/","name").
  dnl These bugs require stripping trailing slash to avoid corrupting
  dnl symlinks with a trailing slash.
  AC_CACHE_CHECK([whether rename honors trailing slash on source],
    [gl_cv_func_rename_slash_src_works],
    [rm -rf conftest.f conftest.f1 conftest.d1 conftest.d2 conftest.d3 conftest.lnk
    touch conftest.f && touch conftest.f1 && mkdir conftest.d1 ||
      AC_MSG_ERROR([cannot create temporary files])
    # Assume that if we have lstat, we can also check symlinks.
    if test $ac_cv_func_lstat = yes; then
      ln -s conftest.f conftest.lnk
    fi
    AC_RUN_IFELSE(
      [AC_LANG_PROGRAM([[
#        include <stdio.h>
#        include <stdlib.h>
         ]],
         [[int result = 0;
           if (rename ("conftest.f1/", "conftest.d3") == 0)
             result |= 1;
           if (rename ("conftest.d1/", "conftest.d2") != 0)
             result |= 2;
#if HAVE_LSTAT
           if (rename ("conftest.lnk/", "conftest.f") == 0)
             result |= 4;
#endif
           return result;
         ]])],
      [gl_cv_func_rename_slash_src_works=yes],
      [gl_cv_func_rename_slash_src_works=no],
      dnl When crosscompiling, assume rename is broken.
      [case "$host_os" in
                 # Guess yes on glibc systems.
         *-gnu*) gl_cv_func_rename_slash_src_works="guessing yes" ;;
                 # If we don't know, assume the worst.
         *)      gl_cv_func_rename_slash_src_works="guessing no" ;;
       esac
      ])
    rm -rf conftest.f conftest.f1 conftest.d1 conftest.d2 conftest.d3 conftest.lnk
  ])
  case "$gl_cv_func_rename_slash_src_works" in
    *yes) ;;
    *)
      REPLACE_RENAME=1
      AC_DEFINE([RENAME_TRAILING_SLASH_SOURCE_BUG], [1],
        [Define if rename does not correctly handle slashes on the source
         argument, such as on Solaris 9 or cygwin 1.5.])
      ;;
  esac

  dnl NetBSD 1.6 and cygwin 1.5.x mistakenly reduce hard link count
  dnl on rename("h1","h2").
  dnl This bug requires stat'ting targets prior to attempting rename.
  AC_CHECK_FUNCS_ONCE([link])
  AC_CACHE_CHECK([whether rename manages hard links correctly],
    [gl_cv_func_rename_link_works],
    [if test $ac_cv_func_link = yes; then
       rm -rf conftest.f conftest.f1
       if touch conftest.f && ln conftest.f conftest.f1 &&
           set x `ls -i conftest.f conftest.f1` && test "$2" = "$4"; then
         AC_RUN_IFELSE(
           [AC_LANG_PROGRAM([[
#             include <stdio.h>
#             include <stdlib.h>
#             include <unistd.h>
              ]],
              [[int result = 0;
                if (rename ("conftest.f", "conftest.f1"))
                  result |= 1;
                if (unlink ("conftest.f1"))
                  result |= 2;
                if (rename ("conftest.f", "conftest.f"))
                  result |= 4;
                if (rename ("conftest.f1", "conftest.f1") == 0)
                  result |= 8;
                return result;
              ]])],
           [gl_cv_func_rename_link_works=yes],
           [gl_cv_func_rename_link_works=no],
           dnl When crosscompiling, assume rename is broken.
           [case "$host_os" in
                      # Guess yes on glibc systems.
              *-gnu*) gl_cv_func_rename_link_works="guessing yes" ;;
                      # If we don't know, assume the worst.
              *)      gl_cv_func_rename_link_works="guessing no" ;;
            esac
           ])
       else
         gl_cv_func_rename_link_works="guessing no"
       fi
       rm -rf conftest.f conftest.f1
     else
       gl_cv_func_rename_link_works=yes
     fi
    ])
  case "$gl_cv_func_rename_link_works" in
    *yes) ;;
    *)
      REPLACE_RENAME=1
      AC_DEFINE([RENAME_HARD_LINK_BUG], [1],
        [Define if rename fails to leave hard links alone, as on NetBSD 1.6
         or Cygwin 1.5.])
      ;;
  esac

  dnl Cygwin 1.5.x mistakenly allows rename("dir","file").
  dnl mingw mistakenly forbids rename("dir1","dir2").
  dnl These bugs require stripping trailing slash to avoid corrupting
  dnl symlinks with a trailing slash.
  AC_CACHE_CHECK([whether rename manages existing destinations correctly],
    [gl_cv_func_rename_dest_works],
    [rm -rf conftest.f conftest.d1 conftest.d2
    touch conftest.f && mkdir conftest.d1 conftest.d2 ||
      AC_MSG_ERROR([cannot create temporary files])
    AC_RUN_IFELSE(
      [AC_LANG_PROGRAM([[
#        include <stdio.h>
#        include <stdlib.h>
         ]],
         [[int result = 0;
           if (rename ("conftest.d1", "conftest.d2") != 0)
             result |= 1;
           if (rename ("conftest.d2", "conftest.f") == 0)
             result |= 2;
           return result;
         ]])],
      [gl_cv_func_rename_dest_works=yes],
      [gl_cv_func_rename_dest_works=no],
      dnl When crosscompiling, assume rename is broken.
      [case "$host_os" in
                 # Guess yes on glibc systems.
         *-gnu*) gl_cv_func_rename_dest_works="guessing yes" ;;
                 # If we don't know, assume the worst.
         *)      gl_cv_func_rename_dest_works="guessing no" ;;
       esac
      ])
    rm -rf conftest.f conftest.d1 conftest.d2
  ])
  case "$gl_cv_func_rename_dest_works" in
    *yes) ;;
    *)
      REPLACE_RENAME=1
      AC_DEFINE([RENAME_DEST_EXISTS_BUG], [1],
        [Define if rename does not work when the destination file exists,
         as on Cygwin 1.5 or Windows.])
      ;;
  esac
])
