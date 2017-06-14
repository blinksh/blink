# backupfile.m4 serial 14
dnl Copyright (C) 2002-2006, 2009-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

dnl Prerequisites of lib/backupfile.c.
AC_DEFUN([gl_BACKUPFILE],
[
  AC_REQUIRE([gl_CHECK_TYPE_STRUCT_DIRENT_D_INO])
  AC_REQUIRE([AC_SYS_LONG_FILE_NAMES])
  AC_CHECK_FUNCS_ONCE([pathconf])
])
