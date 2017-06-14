# nproc.m4 serial 5
dnl Copyright (C) 2009-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_NPROC],
[
  gl_PREREQ_NPROC
])

# Prerequisites of lib/nproc.c.
AC_DEFUN([gl_PREREQ_NPROC],
[
  dnl Persuade glibc <sched.h> to declare CPU_SETSIZE, CPU_ISSET etc.
  AC_REQUIRE([AC_USE_SYSTEM_EXTENSIONS])

  AC_CHECK_HEADERS([sys/pstat.h sys/sysmp.h sys/param.h],,,
    [AC_INCLUDES_DEFAULT])
  dnl <sys/sysctl.h> requires <sys/param.h> on OpenBSD 4.0.
  AC_CHECK_HEADERS([sys/sysctl.h],,,
    [AC_INCLUDES_DEFAULT
     #if HAVE_SYS_PARAM_H
     # include <sys/param.h>
     #endif
    ])

  AC_CHECK_FUNCS([sched_getaffinity sched_getaffinity_np \
                  pstat_getdynamic sysmp sysctl])

  dnl Test whether sched_getaffinity has the expected declaration.
  dnl glibc 2.3.[0-2]:
  dnl   int sched_getaffinity (pid_t, unsigned int, unsigned long int *);
  dnl glibc 2.3.3:
  dnl   int sched_getaffinity (pid_t, cpu_set_t *);
  dnl glibc >= 2.3.4:
  dnl   int sched_getaffinity (pid_t, size_t, cpu_set_t *);
  if test $ac_cv_func_sched_getaffinity = yes; then
    AC_CACHE_CHECK([for glibc compatible sched_getaffinity],
      [gl_cv_func_sched_getaffinity3],
      [AC_COMPILE_IFELSE(
         [AC_LANG_PROGRAM(
            [[#include <errno.h>
              #include <sched.h>]],
            [[sched_getaffinity (0, 0, (cpu_set_t *) 0);]])],
         [gl_cv_func_sched_getaffinity3=yes],
         [gl_cv_func_sched_getaffinity3=no])
      ])
    if test $gl_cv_func_sched_getaffinity3 = yes; then
      AC_DEFINE([HAVE_SCHED_GETAFFINITY_LIKE_GLIBC], [1],
        [Define to 1 if sched_getaffinity has a glibc compatible declaration.])
    fi
  fi
])
