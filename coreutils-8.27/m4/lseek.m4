# lseek.m4 serial 10
dnl Copyright (C) 2007, 2009-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_LSEEK],
[
  AC_REQUIRE([gl_UNISTD_H_DEFAULTS])

  AC_REQUIRE([AC_CANONICAL_HOST])
  AC_REQUIRE([AC_PROG_CC])
  AC_CHECK_HEADERS_ONCE([unistd.h])
  AC_CACHE_CHECK([whether lseek detects pipes], [gl_cv_func_lseek_pipe],
    [case "$host_os" in
       mingw*)
         dnl Native Windows.
         dnl The result of lseek (fd, (off_t)0, SEEK_CUR) or
         dnl SetFilePointer(handle, 0, NULL, FILE_CURRENT)
         dnl for a pipe depends on the environment: In a Cygwin 1.5
         dnl environment it succeeds (wrong); in a Cygwin 1.7 environment
         dnl it fails with a wrong errno value.
         gl_cv_func_lseek_pipe=no
         ;;
       *)
         if test $cross_compiling = no; then
           AC_LINK_IFELSE([AC_LANG_PROGRAM([[
#include <sys/types.h> /* for off_t */
#include <stdio.h> /* for SEEK_CUR */
#if HAVE_UNISTD_H
# include <unistd.h>
#else /* on Windows with MSVC */
# include <io.h>
#endif
]], [[
  /* Exit with success only if stdin is seekable.  */
  return lseek (0, (off_t)0, SEEK_CUR) < 0;
]])],
             [if test -s conftest$ac_exeext \
                 && ./conftest$ac_exeext < conftest.$ac_ext \
                 && test 1 = "`echo hi \
                   | { ./conftest$ac_exeext; echo $?; cat >/dev/null; }`"; then
                gl_cv_func_lseek_pipe=yes
              else
                gl_cv_func_lseek_pipe=no
              fi
             ],
             [gl_cv_func_lseek_pipe=no])
         else
           AC_COMPILE_IFELSE(
             [AC_LANG_SOURCE([[
#if defined __BEOS__
/* BeOS mistakenly return 0 when trying to seek on pipes.  */
  Choke me.
#endif]])],
             [gl_cv_func_lseek_pipe=yes], [gl_cv_func_lseek_pipe=no])
         fi
         ;;
     esac
    ])
  if test $gl_cv_func_lseek_pipe = no; then
    REPLACE_LSEEK=1
    AC_DEFINE([LSEEK_PIPE_BROKEN], [1],
      [Define to 1 if lseek does not detect pipes.])
  fi

  AC_REQUIRE([gl_SYS_TYPES_H])
  if test $WINDOWS_64_BIT_OFF_T = 1; then
    REPLACE_LSEEK=1
  fi
])
