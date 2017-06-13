# mkdir-p.m4 serial 15
dnl Copyright (C) 2002-2006, 2009-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_MKDIR_PARENTS],
[
  dnl Prerequisites of lib/dirchownmod.c.
  AC_CHECK_FUNCS_ONCE([fchmod])
])
