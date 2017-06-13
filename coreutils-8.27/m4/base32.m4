# base32.m4 serial 4
dnl Copyright (C) 2004, 2006, 2009-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_BASE32],
[
  gl_PREREQ_BASE32
])

# Prerequisites of lib/base32.c.
AC_DEFUN([gl_PREREQ_BASE32], [
  AC_REQUIRE([AC_C_RESTRICT])
])
