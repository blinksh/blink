# fclose.m4 serial 7
dnl Copyright (C) 2008-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_FCLOSE],
[
  AC_REQUIRE([gl_STDIO_H_DEFAULTS])
  AC_REQUIRE([AC_CANONICAL_HOST])

  gl_FUNC_FFLUSH_STDIN
  if test $gl_cv_func_fflush_stdin != yes; then
    REPLACE_FCLOSE=1
  fi

  AC_REQUIRE([gl_FUNC_CLOSE])
  if test $REPLACE_CLOSE = 1; then
    REPLACE_FCLOSE=1
  fi

  case "$host_os" in
    openedition) REPLACE_FCLOSE=1 ;;
  esac
])
