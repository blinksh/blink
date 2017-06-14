# serial 3   -*- Autoconf -*-
# Copyright (C) 2006-2007, 2009-2017 Free Software Foundation, Inc.
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

# From Jim Meyering
# Provide <selinux/context.h>, if necessary.

AC_DEFUN([gl_HEADERS_SELINUX_CONTEXT_H],
[
  AC_REQUIRE([gl_LIBSELINUX])
  if test "$with_selinux" != no; then
    AC_CHECK_HEADERS([selinux/context.h],
                     [SELINUX_CONTEXT_H=],
                     [SELINUX_CONTEXT_H=selinux/context.h])
  else
    SELINUX_CONTEXT_H=selinux/context.h
  fi
  AC_SUBST([SELINUX_CONTEXT_H])
  AM_CONDITIONAL([GL_GENERATE_SELINUX_CONTEXT_H], [test -n "$SELINUX_CONTEXT_H"])
])
