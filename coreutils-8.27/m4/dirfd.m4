# serial 24   -*- Autoconf -*-

dnl Find out how to get the file descriptor associated with an open DIR*.

# Copyright (C) 2001-2006, 2008-2017 Free Software Foundation, Inc.
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

dnl From Jim Meyering

AC_DEFUN([gl_FUNC_DIRFD],
[
  AC_REQUIRE([gl_DIRENT_H_DEFAULTS])

  dnl Persuade glibc <dirent.h> to declare dirfd().
  AC_REQUIRE([AC_USE_SYSTEM_EXTENSIONS])

  AC_CHECK_FUNCS([dirfd])
  AC_CHECK_DECLS([dirfd], , ,
    [[#include <sys/types.h>
      #include <dirent.h>]])
  if test $ac_cv_have_decl_dirfd = no; then
    HAVE_DECL_DIRFD=0
  fi

  AC_CACHE_CHECK([whether dirfd is a macro],
    gl_cv_func_dirfd_macro,
    [AC_EGREP_CPP([dirent_header_defines_dirfd], [
#include <sys/types.h>
#include <dirent.h>
#ifdef dirfd
 dirent_header_defines_dirfd
#endif],
       gl_cv_func_dirfd_macro=yes,
       gl_cv_func_dirfd_macro=no)])

  # Use the replacement if we have no function or macro with that name,
  # or if OS/2 kLIBC whose dirfd() does not work.
  # Replace only if the system declares dirfd already.
  case $ac_cv_func_dirfd,$gl_cv_func_dirfd_macro,$host_os,$ac_cv_have_decl_dirfd in
    no,no,*,yes | *,*,os2*,yes)
      REPLACE_DIRFD=1
      AC_DEFINE([REPLACE_DIRFD], [1],
        [Define to 1 if gnulib's dirfd() replacement is used.]);;
  esac
])

dnl Prerequisites of lib/dirfd.c.
AC_DEFUN([gl_PREREQ_DIRFD],
[
  AC_CACHE_CHECK([how to get the file descriptor associated with an open DIR*],
                 [gl_cv_sys_dir_fd_member_name],
    [
      dirfd_save_CFLAGS=$CFLAGS
      for ac_expr in d_fd dd_fd; do

        CFLAGS="$CFLAGS -DDIR_FD_MEMBER_NAME=$ac_expr"
        AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
           #include <sys/types.h>
           #include <dirent.h>]],
          [[DIR *dir_p = opendir("."); (void) dir_p->DIR_FD_MEMBER_NAME;]])],
          [dir_fd_found=yes]
        )
        CFLAGS=$dirfd_save_CFLAGS
        test "$dir_fd_found" = yes && break
      done
      test "$dir_fd_found" = yes || ac_expr=no_such_member

      gl_cv_sys_dir_fd_member_name=$ac_expr
    ]
  )
  if test $gl_cv_sys_dir_fd_member_name != no_such_member; then
    AC_DEFINE_UNQUOTED([DIR_FD_MEMBER_NAME],
      [$gl_cv_sys_dir_fd_member_name],
      [the name of the file descriptor member of DIR])
  fi
  AH_VERBATIM([DIR_TO_FD],
              [#ifdef DIR_FD_MEMBER_NAME
# define DIR_TO_FD(Dir_p) ((Dir_p)->DIR_FD_MEMBER_NAME)
#else
# define DIR_TO_FD(Dir_p) -1
#endif
])
])
