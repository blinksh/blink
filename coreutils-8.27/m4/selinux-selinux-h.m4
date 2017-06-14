# serial 5   -*- Autoconf -*-
# Copyright (C) 2006-2007, 2009-2017 Free Software Foundation, Inc.
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

# From Jim Meyering
# Provide <selinux/selinux.h>, if necessary.
# If it is already present, provide wrapper functions to guard against
# misbehavior from getfilecon, lgetfilecon, and fgetfilecon.

AC_DEFUN([gl_HEADERS_SELINUX_SELINUX_H],
[
  AC_REQUIRE([gl_LIBSELINUX])
  if test "$with_selinux" != no; then
    AC_CHECK_HEADERS([selinux/selinux.h])

    if test "$ac_cv_header_selinux_selinux_h" = yes; then
      # We do have <selinux/selinux.h>, so do compile getfilecon.c
      # and arrange to use its wrappers.
      gl_CHECK_NEXT_HEADERS([selinux/selinux.h])
      AC_DEFINE([getfilecon], [rpl_getfilecon],
                [Always use our getfilecon wrapper.])
      AC_DEFINE([lgetfilecon], [rpl_lgetfilecon],
                [Always use our lgetfilecon wrapper.])
      AC_DEFINE([fgetfilecon], [rpl_fgetfilecon],
                [Always use our fgetfilecon wrapper.])
    fi

    case "$ac_cv_search_setfilecon:$ac_cv_header_selinux_selinux_h" in
      no:*) # already warned
        ;;
      *:no)
        AC_MSG_WARN([libselinux was found but selinux/selinux.h is missing.])
        AC_MSG_WARN([AC_PACKAGE_NAME will be compiled without SELinux support.])
    esac
  else
    # Do as if <selinux/selinux.h> does not exist, even if
    # AC_CHECK_HEADERS_ONCE has already determined that it exists.
    AC_DEFINE([HAVE_SELINUX_SELINUX_H], [0])
  fi
])

AC_DEFUN([gl_LIBSELINUX],
[
  AC_REQUIRE([AC_CANONICAL_HOST])
  AC_REQUIRE([AC_CANONICAL_BUILD])

  AC_ARG_WITH([selinux],
    AS_HELP_STRING([--without-selinux], [do not use SELinux, even on systems with SELinux]),
    [], [with_selinux=maybe])

  LIB_SELINUX=
  if test "$with_selinux" != no; then
    gl_save_LIBS=$LIBS
    AC_SEARCH_LIBS([setfilecon], [selinux],
                   [test "$ac_cv_search_setfilecon" = "none required" ||
                    LIB_SELINUX=$ac_cv_search_setfilecon])
    LIBS=$gl_save_LIBS
  fi
  AC_SUBST([LIB_SELINUX])

  # Warn if SELinux is found but libselinux is absent;
  if test "$ac_cv_search_setfilecon" = no; then
    if test "$host" = "$build" && test -d /selinux; then
      AC_MSG_WARN([This system supports SELinux but libselinux is missing.])
      AC_MSG_WARN([AC_PACKAGE_NAME will be compiled without SELinux support.])
    fi
    with_selinux=no
  fi
])
