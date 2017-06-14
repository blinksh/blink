# iswblank.m4 serial 4
dnl Copyright (C) 2011-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_ISWBLANK],
[
  AC_REQUIRE([gl_WCTYPE_H_DEFAULTS])
  AC_REQUIRE([gl_WCTYPE_H])
  dnl Persuade glibc <wctype.h> to declare iswblank().
  AC_REQUIRE([gl_USE_SYSTEM_EXTENSIONS])
  AC_CHECK_FUNCS_ONCE([iswblank])
  AC_CHECK_DECLS([iswblank], , , [[
/* Tru64 with Desktop Toolkit C has a bug: <stdio.h> must be included before
   <wchar.h>.
   BSD/OS 4.0.1 has a bug: <stddef.h>, <stdio.h> and <time.h> must be included
   before <wchar.h>.  */
#include <stddef.h>
#include <stdio.h>
#include <time.h>
#include <wchar.h>
#include <wctype.h>
]])
  if test $ac_cv_func_iswblank = no; then
    HAVE_ISWBLANK=0
    if test $ac_cv_have_decl_iswblank = yes; then
      REPLACE_ISWBLANK=1
    fi
  fi
  if test $HAVE_ISWCNTRL = 0 || test $REPLACE_ISWCNTRL = 1; then
    dnl Redefine all of iswcntrl, ..., towupper in <wctype.h>.
    :
  else
    if test $HAVE_ISWBLANK = 0 || test $REPLACE_ISWBLANK = 1; then
      dnl Redefine only iswblank.
      :
    fi
  fi

])
