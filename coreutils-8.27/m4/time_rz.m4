dnl Time zone functions: tzalloc, localtime_rz, etc.

dnl Copyright (C) 2015-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

dnl Written by Paul Eggert.

AC_DEFUN([gl_TIME_RZ],
[
  AC_REQUIRE([gl_USE_SYSTEM_EXTENSIONS])
  AC_REQUIRE([gl_HEADER_SYS_TIME_H_DEFAULTS])
  AC_REQUIRE([AC_STRUCT_TIMEZONE])
  AC_CHECK_FUNCS_ONCE([tzset])

  AC_CHECK_TYPES([timezone_t], [], [], [[#include <time.h>]])
  if test "$ac_cv_type_timezone_t" = yes; then
    HAVE_TIMEZONE_T=1
  fi
])
