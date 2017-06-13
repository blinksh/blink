# fdatasync.m4 serial 4
dnl Copyright (C) 2008-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_FDATASYNC],
[
  AC_REQUIRE([gl_UNISTD_H_DEFAULTS])

  dnl Using AC_CHECK_FUNCS_ONCE would break our subsequent AC_SEARCH_LIBS
  AC_CHECK_DECLS_ONCE([fdatasync])
  LIB_FDATASYNC=
  AC_SUBST([LIB_FDATASYNC])

  if test $ac_cv_have_decl_fdatasync = no; then
    HAVE_DECL_FDATASYNC=0
    dnl Mac OS X 10.7 has fdatasync but does not declare it.
    AC_CHECK_FUNCS([fdatasync])
    if test $ac_cv_func_fdatasync = no; then
      HAVE_FDATASYNC=0
    fi
  else
    dnl Solaris <= 2.6 has fdatasync() in libposix4.
    dnl Solaris 7..10 has it in librt.
    gl_saved_libs=$LIBS
    AC_SEARCH_LIBS([fdatasync], [rt posix4],
                   [test "$ac_cv_search_fdatasync" = "none required" ||
                    LIB_FDATASYNC=$ac_cv_search_fdatasync])
    LIBS=$gl_saved_libs
  fi
])
