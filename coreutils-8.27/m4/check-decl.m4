#serial 26
# Check declarations for this package.

dnl Copyright (C) 1997-2017 Free Software Foundation, Inc.

dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.


dnl This is just a wrapper function to encapsulate this kludge.
dnl Putting it in a separate file like this helps share it between
dnl different packages.
AC_DEFUN([gl_CHECK_DECLS],
[
  AC_REQUIRE([AC_HEADER_TIME])

  AC_CHECK_HEADERS_ONCE([grp.h pwd.h])
  headers='
#include <sys/types.h>

#include <unistd.h>

#if HAVE_GRP_H
# include <grp.h>
#endif

#if HAVE_PWD_H
# include <pwd.h>
#endif
'
  AC_CHECK_DECLS([
    getgrgid,
    getpwuid,
    ttyname], , , $headers)

  AC_CHECK_DECLS_ONCE([geteuid])
  AC_CHECK_DECLS_ONCE([getlogin])
  AC_CHECK_DECLS_ONCE([getuid])
])
