# nl_langinfo.m4 serial 5
dnl Copyright (C) 2009-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_NL_LANGINFO],
[
  AC_REQUIRE([gl_LANGINFO_H_DEFAULTS])
  AC_REQUIRE([gl_LANGINFO_H])
  AC_CHECK_FUNCS_ONCE([nl_langinfo])
  AC_REQUIRE([AC_CANONICAL_HOST]) dnl for cross-compiles
  if test $ac_cv_func_nl_langinfo = yes; then
    # On Irix 6.5, YESEXPR is defined, but nl_langinfo(YESEXPR) is broken.
    AC_CACHE_CHECK([whether YESEXPR works],
      [gl_cv_func_nl_langinfo_yesexpr_works],
      [AC_RUN_IFELSE(
         [AC_LANG_PROGRAM([[#include <langinfo.h>
]], [[return !*nl_langinfo(YESEXPR);
]])],
         [gl_cv_func_nl_langinfo_yesexpr_works=yes],
         [gl_cv_func_nl_langinfo_yesexpr_works=no],
         [
         case "$host_os" in
                   # Guess no on irix systems.
           irix*)  gl_cv_func_nl_langinfo_yesexpr_works="guessing no";;
                   # Guess yes elsewhere.
           *)      gl_cv_func_nl_langinfo_yesexpr_works="guessing yes";;
         esac
         ])
      ])
    case $gl_cv_func_nl_langinfo_yesexpr_works in
      *yes) FUNC_NL_LANGINFO_YESEXPR_WORKS=1 ;;
      *)    FUNC_NL_LANGINFO_YESEXPR_WORKS=0 ;;
    esac
    AC_DEFINE_UNQUOTED([FUNC_NL_LANGINFO_YESEXPR_WORKS],
      [$FUNC_NL_LANGINFO_YESEXPR_WORKS],
      [Define to 1 if nl_langinfo (YESEXPR) returns a non-empty string.])
    if test $HAVE_LANGINFO_CODESET = 1 && test $HAVE_LANGINFO_ERA = 1 \
        && test $FUNC_NL_LANGINFO_YESEXPR_WORKS = 1; then
      :
    else
      REPLACE_NL_LANGINFO=1
      AC_DEFINE([REPLACE_NL_LANGINFO], [1],
        [Define if nl_langinfo exists but is overridden by gnulib.])
    fi
  else
    HAVE_NL_LANGINFO=0
  fi
])
