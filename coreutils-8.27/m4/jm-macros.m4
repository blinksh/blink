#serial 111   -*- autoconf -*-

dnl Misc type-related macros for coreutils.

# Copyright (C) 1998-2017 Free Software Foundation, Inc.

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

# Written by Jim Meyering.

AC_DEFUN([coreutils_MACROS],
[
  AM_MISSING_PROG(HELP2MAN, help2man)
  AC_SUBST([MAN])

  dnl This macro actually runs replacement code.  See isc-posix.m4.
  AC_REQUIRE([AC_ISC_POSIX])dnl

  gl_CHECK_ALL_TYPES

  AC_REQUIRE([gl_CHECK_DECLS])

  AC_REQUIRE([gl_PREREQ])

  AC_REQUIRE([AC_FUNC_FSEEKO])

  # By default, argmatch should fail calling usage (EXIT_FAILURE).
  AC_DEFINE([ARGMATCH_DIE], [usage (EXIT_FAILURE)],
            [Define to the function xargmatch calls on failures.])
  AC_DEFINE([ARGMATCH_DIE_DECL], [void usage (int _e)],
            [Define to the declaration of the xargmatch failure function.])

  # used by shred
  AC_CHECK_FUNCS_ONCE([directio])

  coreutils_saved_libs=$LIBS
    LIBS="$LIBS $LIB_SELINUX"
    # Used by selinux.c.
    AC_CHECK_FUNCS([mode_to_security_class], [], [])
    # Used by install.c.
    AC_CHECK_FUNCS([matchpathcon_init_prefix], [],
    [
      if test "$with_selinux" != no; then
        case "$ac_cv_search_setfilecon:$ac_cv_header_selinux_selinux_h" in
          no:*) # SELinux disabled
            ;;
          *:no) # SELinux disabled
            ;;
          *)
          AC_MSG_WARN([SELinux enabled, but matchpathcon_init_prefix not found])
          AC_MSG_WARN([The install utility may run slowly])
        esac
      fi
    ])
  LIBS=$coreutils_saved_libs

  # Used by sort.c.
  AC_CHECK_FUNCS_ONCE([nl_langinfo])
  # Used by timeout.c
  AC_CHECK_FUNCS_ONCE([setrlimit prctl])

  # Used by tail.c.
  AC_CHECK_FUNCS([inotify_init],
    [AC_DEFINE([HAVE_INOTIFY], [1],
     [Define to 1 if you have usable inotify support.])])

  AC_CHECK_FUNCS_ONCE([
    endgrent
    endpwent
    fallocate
    fchown
    fchmod
    ftruncate
    iswspace
    mkfifo
    mbrlen
    setgroups
    sethostname
    siginterrupt
    sync
    syncfs
    sysctl
    sysinfo
    tcgetpgrp
  ])

  # These checks are for Interix, to avoid its getgr* functions, in favor
  # of these replacements.  The replacement functions are much more efficient
  # because they do not query the domain controller for user information
  # when it is not needed.
  AC_CHECK_FUNCS_ONCE([
    getgrgid_nomembers
    getgrnam_nomembers
    getgrent_nomembers
  ])

  dnl This can't use AC_REQUIRE; I'm not quite sure why.
  cu_PREREQ_STAT_PROG

  # for dd.c and shred.c
  #
  # Use fdatasync only if declared.  On MacOS X 10.7, fdatasync exists but
  # is not declared, and is ineffective.
  LIB_FDATASYNC=
  AC_SUBST([LIB_FDATASYNC])
  AC_CHECK_DECLS_ONCE([fdatasync])
  if test $ac_cv_have_decl_fdatasync = yes; then
    coreutils_saved_libs=$LIBS
    AC_SEARCH_LIBS([fdatasync], [rt posix4],
                   [test "$ac_cv_search_fdatasync" = "none required" ||
                    LIB_FDATASYNC=$ac_cv_search_fdatasync])
    AC_CHECK_FUNCS([fdatasync])
    LIBS=$coreutils_saved_libs
  fi

  # Check whether libcap is usable -- for ls --color support
  LIB_CAP=
  AC_ARG_ENABLE([libcap],
    AC_HELP_STRING([--disable-libcap], [disable libcap support]))
  if test "X$enable_libcap" != "Xno"; then
    AC_CHECK_LIB([cap], [cap_get_file],
      [AC_CHECK_HEADER([sys/capability.h],
        [LIB_CAP=-lcap
         AC_DEFINE([HAVE_CAP], [1], [libcap usability])]
      )])
    if test "X$LIB_CAP" = "X"; then
      if test "X$enable_libcap" = "Xyes"; then
        AC_MSG_ERROR([libcap library was not found or not usable])
      else
        AC_MSG_WARN([libcap library was not found or not usable.])
        AC_MSG_WARN([AC_PACKAGE_NAME will be built without capability support.])
      fi
    fi
  else
    AC_MSG_WARN([libcap support disabled by user])
  fi
  AC_SUBST([LIB_CAP])

  # See if linking 'seq' requires -lm.
  # It does on nearly every system.  The single exception (so far) is
  # BeOS which has all the math functions in the normal runtime library
  # and doesn't have a separate math library.

  AC_SUBST([SEQ_LIBM])
  ac_seq_body='
     static double x, y;
     x = floor (x);
     x = rint (x);
     x = modf (x, &y);'
  AC_TRY_LINK([#include <math.h>], [$ac_seq_body], ,
    [ac_seq_save_LIBS="$LIBS"
     LIBS="$LIBS -lm"
     AC_TRY_LINK([#include <math.h>], [$ac_seq_body], [SEQ_LIBM=-lm])
     LIBS="$ac_seq_save_LIBS"
    ])


  # See is fpsetprec() required to use extended double precision
  # This is needed on 32 bit FreeBSD to give accurate conversion of:
  # `numfmt 9223372036854775808`
  AC_TRY_LINK([#include <ieeefp.h>],
    [#ifdef __i386__
      fpsetprec(FP_PE);
     #else
     # error not required on 64 bit
     #endif
    ], [ac_have_fpsetprec=yes], [ac_have_fpsetprec=no])
  if test "$ac_have_fpsetprec" = "yes" ; then
    AC_DEFINE([HAVE_FPSETPREC], 1, [whether fpsetprec is present and required])
  fi

  AC_REQUIRE([AM_LANGINFO_CODESET])

  # Accept configure options: --with-tty-group[=GROUP], --without-tty-group
  # You can determine the group of a TTY via 'stat --format %G /dev/tty'
  # Omitting this option is equivalent to using --without-tty-group.
  AC_ARG_WITH([tty-group],
    AS_HELP_STRING([--with-tty-group[[[=NAME]]]],
      [group used by system for TTYs, "tty" when not specified]
      [ (default: do not rely on any group used for TTYs)]),
    [tty_group_name=$withval],
    [tty_group_name=no])

  if test "x$tty_group_name" != xno; then
    if test "x$tty_group_name" = xyes; then
      tty_group_name=tty
    fi
    AC_MSG_NOTICE([TTY group used by system set to "$tty_group_name"])
    AC_DEFINE_UNQUOTED([TTY_GROUP_NAME], ["$tty_group_name"],
      [group used by system for TTYs])
  fi
])

AC_DEFUN([gl_CHECK_ALL_HEADERS],
[
  AC_CHECK_HEADERS_ONCE([
    hurd.h
    linux/falloc.h
    linux/fs.h
    paths.h
    priv.h
    stropts.h
    sys/param.h
    sys/systeminfo.h
    syslog.h
  ])
  AC_CHECK_HEADERS([sys/sysctl.h], [], [],
    [AC_INCLUDES_DEFAULT
     [#if HAVE_SYS_PARAM_H
       #include <sys/param.h>
      #endif]])
])

# This macro must be invoked before any tests that run the compiler.
AC_DEFUN([gl_CHECK_ALL_TYPES],
[
  dnl Checks for typedefs, structures, and compiler characteristics.
  AC_REQUIRE([gl_BIGENDIAN])
  AC_REQUIRE([AC_C_VOLATILE])
  AC_REQUIRE([AC_C_INLINE])
  AC_REQUIRE([AC_TYPE_UNSIGNED_LONG_LONG_INT])

  AC_REQUIRE([gl_CHECK_ALL_HEADERS])
  AC_CHECK_MEMBERS(
    [struct stat.st_author],,,
    [$ac_includes_default
#include <sys/stat.h>
  ])
  AC_REQUIRE([AC_STRUCT_ST_BLOCKS])

  AC_REQUIRE([AC_TYPE_GETGROUPS])
  AC_REQUIRE([AC_TYPE_MBSTATE_T])
  AC_REQUIRE([AC_TYPE_MODE_T])
  AC_REQUIRE([AC_TYPE_OFF_T])
  AC_REQUIRE([AC_TYPE_PID_T])
  AC_REQUIRE([AC_TYPE_SIZE_T])
  AC_REQUIRE([AC_TYPE_UID_T])
  AC_CHECK_TYPE([ino_t], [unsigned long int])

  dnl This relies on the fact that Autoconf's implementation of
  dnl AC_CHECK_TYPE checks includes unistd.h.
  AC_CHECK_TYPE([major_t], [unsigned int])
  AC_CHECK_TYPE([minor_t], [unsigned int])

  AC_REQUIRE([AC_HEADER_MAJOR])
])
