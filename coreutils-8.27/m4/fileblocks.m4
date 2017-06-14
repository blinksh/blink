# fileblocks.m4 serial 6
dnl Copyright (C) 2002, 2005-2006, 2009-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FILEBLOCKS],
[
  m4_pushdef([AC_LIBOBJ], [:])
  dnl Note: AC_STRUCT_ST_BLOCKS does AC_LIBOBJ([fileblocks]).
  AC_STRUCT_ST_BLOCKS
  m4_popdef([AC_LIBOBJ])
  dnl The stat-size module depends on this one and also assumes that
  dnl HAVE_STRUCT_STAT_ST_BLOCKS is correctly defined.  So if you
  dnl remove the call above, please make sure that this does not
  dnl introduce a bug into lib/stat-size.h.
])

# Prerequisites of lib/fileblocks.c.
AC_DEFUN([gl_PREREQ_FILEBLOCKS], [
  AC_CHECK_HEADERS_ONCE([sys/param.h])
  :
])
