# boottime.m4 serial 4
# Determine whether this system has infrastructure for obtaining the boot time.

# Copyright (C) 1996-2017 Free Software Foundation, Inc.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# GNULIB_BOOT_TIME([ACTION-IF-FOUND[, ACTION-IF-NOT-FOUND]])
* ----------------------------------------------------------
AC_DEFUN([GNULIB_BOOT_TIME],
[
  AC_CHECK_FUNCS([sysctl])
  AC_CHECK_HEADERS_ONCE([sys/param.h])
  AC_CHECK_HEADERS([sys/sysctl.h], [], [],
    [AC_INCLUDES_DEFAULT
     [#if HAVE_SYS_PARAM_H
       #include <sys/param.h>
      #endif]])
  AC_CHECK_HEADERS_ONCE([utmp.h utmpx.h OS.h])
  AC_CACHE_CHECK(
    [whether we can get the system boot time],
    [gnulib_cv_have_boot_time],
    [
      AC_COMPILE_IFELSE(
       [AC_LANG_PROGRAM(
[AC_INCLUDES_DEFAULT
#if HAVE_SYSCTL && HAVE_SYS_SYSCTL_H
# if HAVE_SYS_PARAM_H
#  include <sys/param.h> /* needed for OpenBSD 3.0 */
# endif
# include <sys/sysctl.h>
#endif
#if HAVE_UTMPX_H
# include <utmpx.h>
#elif HAVE_UTMP_H
# include <utmp.h>
#endif
#if HAVE_OS_H
# include <OS.h>
#endif
],
[[
#if (defined BOOT_TIME                              \
     || (defined CTL_KERN && defined KERN_BOOTTIME) \
     || HAVE_OS_H)
/* your system *does* have the infrastructure to determine boot time */
#else
please_tell_us_how_to_determine_boot_time_on_your_system
#endif
]])],
       [gnulib_cv_have_boot_time=yes],
       [gnulib_cv_have_boot_time=no])
    ])
  AS_IF([test $gnulib_cv_have_boot_time = yes], [$1], [$2])
])
