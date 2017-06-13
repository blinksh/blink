# serial 11

dnl From Jim Meyering.
dnl
dnl Check whether struct dirent has a member named d_type.
dnl

# Copyright (C) 1997, 1999-2004, 2006, 2009-2017 Free Software Foundation, Inc.
#
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_CHECK_TYPE_STRUCT_DIRENT_D_TYPE],
  [AC_CACHE_CHECK([for d_type member in directory struct],
                  gl_cv_struct_dirent_d_type,
     [AC_LINK_IFELSE([AC_LANG_PROGRAM([[
#include <sys/types.h>
#include <dirent.h>
         ]],
         [[struct dirent dp; dp.d_type = 0;]])],
       [gl_cv_struct_dirent_d_type=yes],
       [gl_cv_struct_dirent_d_type=no])
     ]
   )
   if test $gl_cv_struct_dirent_d_type = yes; then
     AC_DEFINE([HAVE_STRUCT_DIRENT_D_TYPE], [1],
       [Define if there is a member named d_type in the struct describing
        directory headers.])
   fi
  ]
)
