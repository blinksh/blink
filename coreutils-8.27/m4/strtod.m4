# strtod.m4 serial 22
dnl Copyright (C) 2002-2003, 2006-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_STRTOD],
[
  AC_REQUIRE([gl_STDLIB_H_DEFAULTS])
  m4_ifdef([gl_FUNC_STRTOD_OBSOLETE], [
    dnl Test whether strtod is declared.
    dnl Don't call AC_FUNC_STRTOD, because it does not have the right guess
    dnl when cross-compiling.
    dnl Don't call AC_CHECK_FUNCS([strtod]) because it would collide with the
    dnl ac_cv_func_strtod variable set by the AC_FUNC_STRTOD macro.
    AC_CHECK_DECLS_ONCE([strtod])
    if test $ac_cv_have_decl_strtod != yes; then
      HAVE_STRTOD=0
    fi
  ])
  if test $HAVE_STRTOD = 1; then
    AC_CACHE_CHECK([whether strtod obeys C99], [gl_cv_func_strtod_works],
      [AC_RUN_IFELSE([AC_LANG_PROGRAM([[
#include <stdlib.h>
#include <math.h>
#include <errno.h>
/* Compare two numbers with ==.
   This is a separate function because IRIX 6.5 "cc -O" miscompiles an
   'x == x' test.  */
static int
numeric_equal (double x, double y)
{
  return x == y;
}
]], [[
  int result = 0;
  {
    /* In some old versions of Linux (2000 or before), strtod mis-parses
       strings with leading '+'.  */
    const char *string = " +69";
    char *term;
    double value = strtod (string, &term);
    if (value != 69 || term != (string + 4))
      result |= 1;
  }
  {
    /* Under Solaris 2.4, strtod returns the wrong value for the
       terminating character under some conditions.  */
    const char *string = "NaN";
    char *term;
    strtod (string, &term);
    if (term != string && *(term - 1) == 0)
      result |= 2;
  }
  {
    /* Older glibc and Cygwin mis-parse "-0x".  */
    const char *string = "-0x";
    char *term;
    double value = strtod (string, &term);
    double zero = 0.0;
    if (1.0 / value != -1.0 / zero || term != (string + 2))
      result |= 4;
  }
  {
    /* Many platforms do not parse hex floats.  */
    const char *string = "0XaP+1";
    char *term;
    double value = strtod (string, &term);
    if (value != 20.0 || term != (string + 6))
      result |= 8;
  }
  {
    /* Many platforms do not parse infinities.  HP-UX 11.31 parses inf,
       but mistakenly sets errno.  */
    const char *string = "inf";
    char *term;
    double value;
    errno = 0;
    value = strtod (string, &term);
    if (value != HUGE_VAL || term != (string + 3) || errno)
      result |= 16;
  }
  {
    /* glibc 2.7 and cygwin 1.5.24 misparse "nan()".  */
    const char *string = "nan()";
    char *term;
    double value = strtod (string, &term);
    if (numeric_equal (value, value) || term != (string + 5))
      result |= 32;
  }
  {
    /* darwin 10.6.1 misparses "nan(".  */
    const char *string = "nan(";
    char *term;
    double value = strtod (string, &term);
    if (numeric_equal (value, value) || term != (string + 3))
      result |= 64;
  }
  return result;
]])],
        [gl_cv_func_strtod_works=yes],
        [gl_cv_func_strtod_works=no],
        [dnl The last known bugs in glibc strtod(), as of this writing,
         dnl were fixed in version 2.8
         AC_EGREP_CPP([Lucky user],
           [
#include <features.h>
#ifdef __GNU_LIBRARY__
 #if ((__GLIBC__ == 2 && __GLIBC_MINOR__ >= 8) || (__GLIBC__ > 2)) \
     && !defined __UCLIBC__
  Lucky user
 #endif
#endif
           ],
           [gl_cv_func_strtod_works="guessing yes"],
           [gl_cv_func_strtod_works="guessing no"])])])
    case "$gl_cv_func_strtod_works" in
      *yes) ;;
      *)
        REPLACE_STRTOD=1
        ;;
    esac
  fi
])

# Prerequisites of lib/strtod.c.
AC_DEFUN([gl_PREREQ_STRTOD], [
  AC_REQUIRE([gl_CHECK_LDEXP_NO_LIBM])
  if test $gl_cv_func_ldexp_no_libm = yes; then
    AC_DEFINE([HAVE_LDEXP_IN_LIBC], [1],
      [Define if the ldexp function is available in libc.])
  fi
])
