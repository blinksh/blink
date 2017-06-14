# serial 7

# Copyright (C) 1996, 1999, 2001, 2004, 2009-2017 Free Software Foundation,
# Inc.
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_HEADER_TIOCGWINSZ_NEEDS_SYS_IOCTL],
[AC_REQUIRE([gl_HEADER_TIOCGWINSZ_IN_TERMIOS_H])
 AC_CACHE_CHECK([whether use of TIOCGWINSZ requires sys/ioctl.h],
                gl_cv_sys_tiocgwinsz_needs_sys_ioctl_h,
  [gl_cv_sys_tiocgwinsz_needs_sys_ioctl_h=no

  if test $gl_cv_sys_tiocgwinsz_needs_termios_h = no; then
    AC_EGREP_CPP([yes],
    [#include <sys/types.h>
#     include <sys/ioctl.h>
#     ifdef TIOCGWINSZ
        yes
#     endif
    ], gl_cv_sys_tiocgwinsz_needs_sys_ioctl_h=yes)
  fi
  ])
  if test $gl_cv_sys_tiocgwinsz_needs_sys_ioctl_h = yes; then
    AC_DEFINE([GWINSZ_IN_SYS_IOCTL], [1],
      [Define if your system defines TIOCGWINSZ in sys/ioctl.h.])
  fi
])
