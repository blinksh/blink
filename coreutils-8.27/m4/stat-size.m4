#serial 1

# Copyright (C) 2011-2017 Free Software Foundation, Inc.
#
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_STAT_SIZE],
[
  # Don't call AC_STRUCT_ST_BLOCKS because it causes bugs.  Details at
  # http://lists.gnu.org/archive/html/bug-gnulib/2011-06/msg00051.html
  AC_CHECK_HEADERS_ONCE([sys/param.h])
])
