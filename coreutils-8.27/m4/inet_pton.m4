# inet_pton.m4 serial 17
dnl Copyright (C) 2006, 2008-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_INET_PTON],
[
  AC_REQUIRE([gl_ARPA_INET_H_DEFAULTS])

  dnl Persuade Solaris <arpa/inet.h> to declare inet_pton.
  AC_REQUIRE([gl_USE_SYSTEM_EXTENSIONS])

  AC_REQUIRE([AC_C_RESTRICT])

  dnl Most platforms that provide inet_pton define it in libc.
  dnl Solaris 8..10 provide inet_pton in libnsl instead.
  dnl Solaris 2.6..7 provide inet_pton in libresolv instead.
  dnl Native Windows provides it in -lws2_32 instead, with a declaration in
  dnl <ws2tcpip.h>, and it uses stdcall calling convention, not cdecl
  dnl (hence we cannot use AC_CHECK_FUNCS, AC_SEARCH_LIBS to find it).
  HAVE_INET_PTON=1
  INET_PTON_LIB=
  gl_PREREQ_SYS_H_WINSOCK2
  if test $HAVE_WINSOCK2_H = 1; then
    AC_CHECK_DECLS([inet_pton],,, [[#include <ws2tcpip.h>]])
    if test $ac_cv_have_decl_inet_pton = yes; then
      dnl It needs to be overridden, because the stdcall calling convention
      dnl is not compliant with POSIX.
      REPLACE_INET_PTON=1
      INET_PTON_LIB="-lws2_32"
    else
      HAVE_DECL_INET_PTON=0
      HAVE_INET_PTON=0
    fi
  else
    gl_save_LIBS=$LIBS
    AC_SEARCH_LIBS([inet_pton], [nsl resolv], [],
      [AC_CHECK_FUNCS([inet_pton])
       if test $ac_cv_func_inet_pton = no; then
         HAVE_INET_PTON=0
       fi
      ])
    LIBS=$gl_save_LIBS

    if test "$ac_cv_search_inet_pton" != "no" \
       && test "$ac_cv_search_inet_pton" != "none required"; then
      INET_PTON_LIB="$ac_cv_search_inet_pton"
    fi

    AC_CHECK_HEADERS_ONCE([netdb.h])
    AC_CHECK_DECLS([inet_pton],,,
      [[#include <arpa/inet.h>
        #if HAVE_NETDB_H
        # include <netdb.h>
        #endif
      ]])
    if test $ac_cv_have_decl_inet_pton = no; then
      HAVE_DECL_INET_PTON=0
    fi
  fi
  AC_SUBST([INET_PTON_LIB])
])

# Prerequisites of lib/inet_pton.c.
AC_DEFUN([gl_PREREQ_INET_PTON], [
  AC_REQUIRE([gl_SOCKET_FAMILIES])
])
