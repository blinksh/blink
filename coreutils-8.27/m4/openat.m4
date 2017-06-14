# serial 45
# See if we need to use our replacement for Solaris' openat et al functions.

dnl Copyright (C) 2004-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

# Written by Jim Meyering.

AC_DEFUN([gl_FUNC_OPENAT],
[
  AC_REQUIRE([gl_FCNTL_H_DEFAULTS])
  AC_REQUIRE([gl_USE_SYSTEM_EXTENSIONS])
  AC_CHECK_FUNCS_ONCE([openat])
  AC_REQUIRE([gl_FUNC_LSTAT_FOLLOWS_SLASHED_SYMLINK])
  case $ac_cv_func_openat+$gl_cv_func_lstat_dereferences_slashed_symlink in
  yes+*yes)
    ;;
  yes+*)
    # Solaris 9 has *at functions, but uniformly mishandles trailing
    # slash in all of them.
    REPLACE_OPENAT=1
    ;;
  *)
    HAVE_OPENAT=0
    ;;
  esac
])

# Prerequisites of lib/openat.c.
AC_DEFUN([gl_PREREQ_OPENAT],
[
  AC_REQUIRE([gl_PROMOTED_TYPE_MODE_T])
  :
])
