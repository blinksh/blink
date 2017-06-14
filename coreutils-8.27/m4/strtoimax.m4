# strtoimax.m4 serial 14
dnl Copyright (C) 2002-2004, 2006, 2009-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_STRTOIMAX],
[
  AC_REQUIRE([gl_INTTYPES_H_DEFAULTS])

  dnl On OSF/1 5.1 with cc, this function is declared but not defined.
  AC_CHECK_FUNCS_ONCE([strtoimax])
  AC_CHECK_DECLS_ONCE([strtoimax])
  if test "$ac_cv_have_decl_strtoimax" != yes; then
    HAVE_DECL_STRTOIMAX=0
  fi

  if test "$ac_cv_func_strtoimax" = yes; then
    HAVE_STRTOIMAX=1
    dnl On AIX 5.1, strtoimax() fails for values outside the 'int' range.
    AC_REQUIRE([AC_CANONICAL_HOST]) dnl for cross-compiles
    AC_CACHE_CHECK([whether strtoimax works], [gl_cv_func_strtoimax],
      [AC_RUN_IFELSE(
         [AC_LANG_SOURCE([[
#include <errno.h>
#include <string.h>
#include <inttypes.h>
int main ()
{
  if (sizeof (intmax_t) > sizeof (int))
    {
      const char *s = "4294967295";
      char *p;
      intmax_t res;
      errno = 0;
      res = strtoimax (s, &p, 10);
      if (p != s + strlen (s))
        return 1;
      if (errno != 0)
        return 2;
      if (res != (intmax_t) 65535 * (intmax_t) 65537)
        return 3;
    }
  else
    {
      const char *s = "2147483647";
      char *p;
      intmax_t res;
      errno = 0;
      res = strtoimax (s, &p, 10);
      if (p != s + strlen (s))
        return 1;
      if (errno != 0)
        return 2;
      if (res != 2147483647)
        return 3;
    }
  return 0;
}
]])],
         [gl_cv_func_strtoimax=yes],
         [gl_cv_func_strtoimax=no],
         [case "$host_os" in
                   # Guess no on AIX 5.
            aix5*) gl_cv_func_strtoimax="guessing no" ;;
                   # Guess yes otherwise.
            *)     gl_cv_func_strtoimax="guessing yes" ;;
          esac
         ])
      ])
    case "$gl_cv_func_strtoimax" in
      *no) REPLACE_STRTOIMAX=1 ;;
    esac
  else
    if test "$ac_cv_have_decl_strtoimax" = yes; then
      # HP-UX 11.11 has "#define strtoimax(...) ..." but no function.
      REPLACE_STRTOIMAX=1
    fi
    HAVE_STRTOIMAX=0
  fi
])

# Prerequisites of lib/strtoimax.c.
AC_DEFUN([gl_PREREQ_STRTOIMAX], [
  AC_CHECK_DECLS([strtoll])
  AC_REQUIRE([AC_TYPE_LONG_LONG_INT])
])
