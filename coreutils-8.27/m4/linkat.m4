# serial 7
# See if we need to provide linkat replacement.

dnl Copyright (C) 2009-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

# Written by Eric Blake.

AC_DEFUN([gl_FUNC_LINKAT],
[
  AC_REQUIRE([gl_FUNC_OPENAT])
  AC_REQUIRE([gl_FUNC_LINK_FOLLOWS_SYMLINK])
  AC_REQUIRE([gl_UNISTD_H_DEFAULTS])
  AC_REQUIRE([gl_USE_SYSTEM_EXTENSIONS])
  AC_REQUIRE([AC_CANONICAL_HOST]) dnl for cross-compiles
  AC_CHECK_FUNCS_ONCE([linkat symlink])
  AC_CHECK_HEADERS_ONCE([sys/param.h])
  if test $ac_cv_func_linkat = no; then
    HAVE_LINKAT=0
  else
    dnl OS X Yosemite has linkat() but it's not sufficient
    dnl to our needs since it doesn't support creating
    dnl hardlinks to symlinks.  Therefore check for that
    dnl capability before considering using the system version.
    AC_CACHE_CHECK([whether linkat() can link symlinks],
      [gl_cv_func_linkat_nofollow],
      [rm -rf conftest.l1 conftest.l2
       ln -s target conftest.l1
       AC_RUN_IFELSE([AC_LANG_PROGRAM(
                        [[#include <fcntl.h>
                          #include <unistd.h>
                        ]],
                        [return linkat (AT_FDCWD, "conftest.l1", AT_FDCWD,
                                            "conftest.l2", 0);
                        ])],
         [gl_cv_func_linkat_nofollow=yes],
         [gl_cv_func_linkat_nofollow=no],
         [case "$host_os" in
           darwin*) gl_cv_func_linkat_nofollow="guessing no" ;;
           *)       gl_cv_func_linkat_nofollow="guessing yes" ;;
          esac])

       rm -rf conftest.l1 conftest.l2])

    case $gl_cv_func_linkat_nofollow in
      *no) LINKAT_SYMLINK_NOTSUP=1 ;;
      *yes) LINKAT_SYMLINK_NOTSUP=0 ;;
    esac

    AC_CACHE_CHECK([whether linkat handles trailing slash correctly],
      [gl_cv_func_linkat_slash],
      [rm -rf conftest.a conftest.b conftest.c conftest.d conftest.e conftest.s
       AC_RUN_IFELSE(
         [AC_LANG_PROGRAM(
            [[#include <unistd.h>
              #include <fcntl.h>
              #include <errno.h>
              #include <stdio.h>
            ]],
            [[int result;
              int fd;
              /* Create a regular file.  */
              fd = open ("conftest.a", O_CREAT | O_EXCL | O_WRONLY, 0600);
              if (fd < 0)
                return 1;
              if (write (fd, "hello", 5) < 5)
                return 2;
              if (close (fd) < 0)
                return 3;
              /* Test whether hard links are supported on the current
                 device.  */
              if (linkat (AT_FDCWD, "conftest.a", AT_FDCWD, "conftest.b",
                          AT_SYMLINK_FOLLOW) < 0)
                return 0;
              result = 0;
              /* Test whether a trailing "/" is treated like "/.".  */
              if (linkat (AT_FDCWD, "conftest.a/", AT_FDCWD, "conftest.c",
                          AT_SYMLINK_FOLLOW) == 0)
                result |= 4;
              if (linkat (AT_FDCWD, "conftest.a", AT_FDCWD, "conftest.d/",
                          AT_SYMLINK_FOLLOW) == 0)
                result |= 8;

              /* On OS X 10.10 a trailing "/" will cause the second path to be
                 dereferenced, and thus will succeed on a dangling symlink.  */
              if (symlink ("conftest.e", "conftest.s") == 0)
                {
                  if (linkat (AT_FDCWD, "conftest.a", AT_FDCWD, "conftest.s/",
                      AT_SYMLINK_FOLLOW) == 0)
                    result |= 16;
                }

              return result;
            ]])],
         [gl_cv_func_linkat_slash=yes],
         [gl_cv_func_linkat_slash=no],
         [# Guess yes on glibc systems, no otherwise.
          case "$host_os" in
            *-gnu*) gl_cv_func_linkat_slash="guessing yes";;
            *)      gl_cv_func_linkat_slash="guessing no";;
          esac
         ])
       rm -rf conftest.a conftest.b conftest.c conftest.d conftest.e conftest.s])
    case "$gl_cv_func_linkat_slash" in
      *yes) gl_linkat_slash_bug=0 ;;
      *)    gl_linkat_slash_bug=1 ;;
    esac

    case "$gl_cv_func_linkat_nofollow" in
      *yes) linkat_nofollow=yes ;;
      *) linkat_nofollow=no ;;
    esac

    if test "$linkat_nofollow" != yes \
       || test $gl_linkat_slash_bug = 1; then
      REPLACE_LINKAT=1
      AC_DEFINE_UNQUOTED([LINKAT_TRAILING_SLASH_BUG], [$gl_linkat_slash_bug],
        [Define to 1 if linkat fails to recognize a trailing slash.])
      AC_DEFINE_UNQUOTED([LINKAT_SYMLINK_NOTSUP], [$LINKAT_SYMLINK_NOTSUP],
        [Define to 1 if linkat can create hardlinks to symlinks])
    fi
  fi
])
