# readutmp.m4 serial 20
dnl Copyright (C) 2002-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_READUTMP],
[
  dnl Persuade utmpx.h to declare utmpxname
  AC_REQUIRE([AC_USE_SYSTEM_EXTENSIONS])

  AC_CHECK_HEADERS_ONCE([utmp.h utmpx.h])
  if test $ac_cv_header_utmp_h = yes || test $ac_cv_header_utmpx_h = yes; then
    dnl Prerequisites of lib/readutmp.h and lib/readutmp.c.
    AC_CHECK_FUNCS_ONCE([utmpname utmpxname])
    AC_CHECK_DECLS([getutent],,,[[
/* <sys/types.h> is a prerequisite of <utmp.h> on FreeBSD 8.0, OpenBSD 4.6.  */
#include <sys/types.h>
#ifdef HAVE_UTMP_H
# include <utmp.h>
#endif
]])
    utmp_includes="\
AC_INCLUDES_DEFAULT
#ifdef HAVE_UTMPX_H
# include <utmpx.h>
#endif
#ifdef HAVE_UTMP_H
# if defined _THREAD_SAFE && defined UTMP_DATA_INIT
   /* When including both utmp.h and utmpx.h on AIX 4.3, with _THREAD_SAFE
      defined, work around the duplicate struct utmp_data declaration.  */
#  define utmp_data gl_aix_4_3_workaround_utmp_data
# endif
# include <utmp.h>
#endif
"
    AC_CHECK_MEMBERS([struct utmpx.ut_user],,,[$utmp_includes])
    AC_CHECK_MEMBERS([struct utmp.ut_user],,,[$utmp_includes])
    AC_CHECK_MEMBERS([struct utmpx.ut_name],,,[$utmp_includes])
    AC_CHECK_MEMBERS([struct utmp.ut_name],,,[$utmp_includes])
    AC_CHECK_MEMBERS([struct utmpx.ut_type],,,[$utmp_includes])
    AC_CHECK_MEMBERS([struct utmp.ut_type],,,[$utmp_includes])
    AC_CHECK_MEMBERS([struct utmpx.ut_pid],,,[$utmp_includes])
    AC_CHECK_MEMBERS([struct utmp.ut_pid],,,[$utmp_includes])
    AC_CHECK_MEMBERS([struct utmpx.ut_id],,,[$utmp_includes])
    AC_CHECK_MEMBERS([struct utmp.ut_id],,,[$utmp_includes])
    AC_CHECK_MEMBERS([struct utmpx.ut_exit],,,[$utmp_includes])
    AC_CHECK_MEMBERS([struct utmp.ut_exit],,,[$utmp_includes])

    AC_CHECK_MEMBERS([struct utmpx.ut_exit.ut_exit],,,[$utmp_includes])
    AC_CHECK_MEMBERS([struct utmp.ut_exit.ut_exit],,,[$utmp_includes])
    AC_CHECK_MEMBERS([struct utmpx.ut_exit.e_exit],,,[$utmp_includes])
    AC_CHECK_MEMBERS([struct utmp.ut_exit.e_exit],,,[$utmp_includes])

    AC_CHECK_MEMBERS([struct utmpx.ut_exit.ut_termination],,,[$utmp_includes])
    AC_CHECK_MEMBERS([struct utmp.ut_exit.ut_termination],,,[$utmp_includes])
    AC_CHECK_MEMBERS([struct utmpx.ut_exit.e_termination],,,[$utmp_includes])
    AC_CHECK_MEMBERS([struct utmp.ut_exit.e_termination],,,[$utmp_includes])
  fi
])
