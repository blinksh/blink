#serial 6

dnl From Jim Meyering.
dnl
dnl See if struct statfs has the f_fstypename member.
dnl If so, define HAVE_STRUCT_STATFS_F_FSTYPENAME.
dnl

# Copyright (C) 1998-1999, 2001, 2004, 2006, 2009-2017 Free Software
# Foundation, Inc.
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FSTYPENAME],
[
  AC_CHECK_MEMBERS([struct statfs.f_fstypename],,,
    [
      #include <sys/types.h>
      #include <sys/param.h>
      #include <sys/mount.h>
    ])
])
