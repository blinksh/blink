# unlinkat.m4 serial 2
dnl Copyright (C) 2004-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

# Written by Jim Meyering.

AC_DEFUN([gl_FUNC_UNLINKAT],
[
  AC_REQUIRE([gl_UNISTD_H_DEFAULTS])
  AC_REQUIRE([gl_USE_SYSTEM_EXTENSIONS])
  AC_CHECK_FUNCS_ONCE([unlinkat])
  AC_REQUIRE([gl_FUNC_UNLINK])
  AC_REQUIRE([gl_FUNC_LSTAT_FOLLOWS_SLASHED_SYMLINK])
  if test $ac_cv_func_unlinkat = no; then
    HAVE_UNLINKAT=0
  else
    case "$gl_cv_func_lstat_dereferences_slashed_symlink" in
      *no)
        # Solaris 9 has *at functions, but uniformly mishandles trailing
        # slash in all of them.
        REPLACE_UNLINKAT=1
        ;;
      *)
        # GNU/Hurd has unlinkat, but it has the same bug as unlink.
        # Darwin has unlinkat, but it has the same UNLINK_PARENT_BUG.
        if test $REPLACE_UNLINK = 1; then
          REPLACE_UNLINKAT=1
        fi
        ;;
    esac
  fi
])
