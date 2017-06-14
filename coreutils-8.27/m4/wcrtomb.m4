# wcrtomb.m4 serial 11
dnl Copyright (C) 2008-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_WCRTOMB],
[
  AC_REQUIRE([gl_WCHAR_H_DEFAULTS])

  AC_REQUIRE([AC_TYPE_MBSTATE_T])
  gl_MBSTATE_T_BROKEN

  AC_CHECK_FUNCS_ONCE([wcrtomb])
  if test $ac_cv_func_wcrtomb = no; then
    HAVE_WCRTOMB=0
    AC_CHECK_DECLS([wcrtomb],,, [[
/* Tru64 with Desktop Toolkit C has a bug: <stdio.h> must be included before
   <wchar.h>.
   BSD/OS 4.0.1 has a bug: <stddef.h>, <stdio.h> and <time.h> must be
   included before <wchar.h>.  */
#include <stddef.h>
#include <stdio.h>
#include <time.h>
#include <wchar.h>
]])
    if test $ac_cv_have_decl_wcrtomb = yes; then
      dnl On Minix 3.1.8, the system's <wchar.h> declares wcrtomb() although
      dnl it does not have the function. Avoid a collision with gnulib's
      dnl replacement.
      REPLACE_WCRTOMB=1
    fi
  else
    if test $REPLACE_MBSTATE_T = 1; then
      REPLACE_WCRTOMB=1
    else
      dnl On AIX 4.3, OSF/1 5.1 and Solaris 10, wcrtomb (NULL, 0, NULL) sometimes
      dnl returns 0 instead of 1.
      AC_REQUIRE([AC_PROG_CC])
      AC_REQUIRE([gt_LOCALE_FR])
      AC_REQUIRE([gt_LOCALE_FR_UTF8])
      AC_REQUIRE([gt_LOCALE_JA])
      AC_REQUIRE([gt_LOCALE_ZH_CN])
      AC_REQUIRE([AC_CANONICAL_HOST]) dnl for cross-compiles
      AC_CACHE_CHECK([whether wcrtomb return value is correct],
        [gl_cv_func_wcrtomb_retval],
        [
          dnl Initial guess, used when cross-compiling or when no suitable locale
          dnl is present.
changequote(,)dnl
          case "$host_os" in
                                     # Guess no on AIX 4, OSF/1 and Solaris.
            aix4* | osf* | solaris*) gl_cv_func_wcrtomb_retval="guessing no" ;;
                                     # Guess yes otherwise.
            *)                       gl_cv_func_wcrtomb_retval="guessing yes" ;;
          esac
changequote([,])dnl
          if test $LOCALE_FR != none || test $LOCALE_FR_UTF8 != none || test $LOCALE_JA != none || test $LOCALE_ZH_CN != none; then
            AC_RUN_IFELSE(
              [AC_LANG_SOURCE([[
#include <locale.h>
#include <string.h>
/* Tru64 with Desktop Toolkit C has a bug: <stdio.h> must be included before
   <wchar.h>.
   BSD/OS 4.0.1 has a bug: <stddef.h>, <stdio.h> and <time.h> must be
   included before <wchar.h>.  */
#include <stddef.h>
#include <stdio.h>
#include <time.h>
#include <wchar.h>
int main ()
{
  int result = 0;
  if (setlocale (LC_ALL, "$LOCALE_FR") != NULL)
    {
      if (wcrtomb (NULL, 0, NULL) != 1)
        result |= 1;
    }
  if (setlocale (LC_ALL, "$LOCALE_FR_UTF8") != NULL)
    {
      if (wcrtomb (NULL, 0, NULL) != 1)
        result |= 2;
    }
  if (setlocale (LC_ALL, "$LOCALE_JA") != NULL)
    {
      if (wcrtomb (NULL, 0, NULL) != 1)
        result |= 4;
    }
  if (setlocale (LC_ALL, "$LOCALE_ZH_CN") != NULL)
    {
      if (wcrtomb (NULL, 0, NULL) != 1)
        result |= 8;
    }
  return result;
}]])],
              [gl_cv_func_wcrtomb_retval=yes],
              [gl_cv_func_wcrtomb_retval=no],
              [:])
          fi
        ])
      case "$gl_cv_func_wcrtomb_retval" in
        *yes) ;;
        *) REPLACE_WCRTOMB=1 ;;
      esac
    fi
  fi
])

# Prerequisites of lib/wcrtomb.c.
AC_DEFUN([gl_PREREQ_WCRTOMB], [
  :
])
