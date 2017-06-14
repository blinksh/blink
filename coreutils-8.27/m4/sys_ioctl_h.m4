# sys_ioctl_h.m4 serial 10
dnl Copyright (C) 2008-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

dnl Written by Bruno Haible.

AC_DEFUN([gl_SYS_IOCTL_H],
[
  dnl Use AC_REQUIRE here, so that the default behavior below is expanded
  dnl once only, before all statements that occur in other macros.
  AC_REQUIRE([gl_SYS_IOCTL_H_DEFAULTS])

  AC_CHECK_HEADERS_ONCE([sys/ioctl.h])
  if test $ac_cv_header_sys_ioctl_h = yes; then
    HAVE_SYS_IOCTL_H=1
    dnl Test whether <sys/ioctl.h> declares ioctl(), or whether some other
    dnl header file, such as <unistd.h> or <stropts.h>, is needed for that.
    AC_CACHE_CHECK([whether <sys/ioctl.h> declares ioctl],
      [gl_cv_decl_ioctl_in_sys_ioctl_h],
      [dnl We cannot use AC_CHECK_DECL because it produces its own messages.
       AC_COMPILE_IFELSE(
         [AC_LANG_PROGRAM(
            [AC_INCLUDES_DEFAULT([#include <sys/ioctl.h>])],
            [(void) ioctl;])],
         [gl_cv_decl_ioctl_in_sys_ioctl_h=yes],
         [gl_cv_decl_ioctl_in_sys_ioctl_h=no])
      ])
  else
    HAVE_SYS_IOCTL_H=0
  fi
  AC_SUBST([HAVE_SYS_IOCTL_H])
  dnl <sys/ioctl.h> is always overridden, because of GNULIB_POSIXCHECK.
  gl_CHECK_NEXT_HEADERS([sys/ioctl.h])

  dnl Check for declarations of anything we want to poison if the
  dnl corresponding gnulib module is not in use.
  gl_WARN_ON_USE_PREPARE([[#include <sys/ioctl.h>
/* Some platforms declare ioctl in the wrong header.  */
#if !(defined __GLIBC__ && !defined __UCLIBC__)
# include <unistd.h>
#endif
    ]], [ioctl])
])

AC_DEFUN([gl_SYS_IOCTL_MODULE_INDICATOR],
[
  dnl Use AC_REQUIRE here, so that the default settings are expanded once only.
  AC_REQUIRE([gl_SYS_IOCTL_H_DEFAULTS])
  gl_MODULE_INDICATOR_SET_VARIABLE([$1])
  dnl Define it also as a C macro, for the benefit of the unit tests.
  gl_MODULE_INDICATOR_FOR_TESTS([$1])
])

AC_DEFUN([gl_SYS_IOCTL_H_DEFAULTS],
[
  GNULIB_IOCTL=0;         AC_SUBST([GNULIB_IOCTL])
  dnl Assume proper GNU behavior unless another module says otherwise.
  SYS_IOCTL_H_HAVE_WINSOCK2_H=0; AC_SUBST([SYS_IOCTL_H_HAVE_WINSOCK2_H])
  SYS_IOCTL_H_HAVE_WINSOCK2_H_AND_USE_SOCKETS=0;
                        AC_SUBST([SYS_IOCTL_H_HAVE_WINSOCK2_H_AND_USE_SOCKETS])
  REPLACE_IOCTL=0;      AC_SUBST([REPLACE_IOCTL])
])
