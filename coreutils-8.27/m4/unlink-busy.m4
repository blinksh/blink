#serial 12

dnl From J. David Anglin.

dnl HPUX and other systems can't unlink shared text that is being executed.

# Copyright (C) 2000-2001, 2004, 2007, 2009-2017 Free Software Foundation, Inc.
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_UNLINK_BUSY_TEXT],
[dnl
  AC_CACHE_CHECK([whether a running program can be unlinked],
    gl_cv_func_unlink_busy_text,
    [
      AC_RUN_IFELSE(
        [AC_LANG_SOURCE(
           [AC_INCLUDES_DEFAULT[
            int
            main (int argc, char **argv)
            {
              int result = 0;
              if (argc == 0)
                result |= 1;
              else if (unlink (argv[0]) != 0)
                result |= 2;
              return result;
            }]])],
      gl_cv_func_unlink_busy_text=yes,
      gl_cv_func_unlink_busy_text=no,
      gl_cv_func_unlink_busy_text=no
      )
    ]
  )

  if test $gl_cv_func_unlink_busy_text = no; then
    INSTALL=$ac_install_sh
  fi
])
