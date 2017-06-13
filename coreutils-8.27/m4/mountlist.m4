# serial 12
dnl Copyright (C) 2002-2006, 2009-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_MOUNTLIST],
[
  gl_LIST_MOUNTED_FILE_SYSTEMS([gl_cv_list_mounted_fs=yes],
                               [gl_cv_list_mounted_fs=no])
])

# Prerequisites of lib/mountlist.c not done by gl_LIST_MOUNTED_FILE_SYSTEMS.
AC_DEFUN([gl_PREREQ_MOUNTLIST_EXTRA],
[
  dnl Note gl_LIST_MOUNTED_FILE_SYSTEMS checks for mntent.h, not sys/mntent.h.
  AC_CHECK_HEADERS([sys/mntent.h])
  AC_HEADER_MAJOR()dnl for use of makedev ()
  gl_FSTYPENAME
])
