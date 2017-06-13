# stat-prog.m4 serial 7
# Record the prerequisites of src/stat.c from the coreutils package.

# Copyright (C) 2002-2017 Free Software Foundation, Inc.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Written by Jim Meyering.

AC_DEFUN([cu_PREREQ_STAT_PROG],
[
  AC_REQUIRE([gl_FSUSAGE])
  AC_REQUIRE([gl_FSTYPENAME])
  AC_CHECK_HEADERS_ONCE([OS.h netinet/in.h sys/param.h sys/vfs.h])

  dnl Check for vfs.h first, since this avoids a warning with nfs_client.h
  dnl on Solaris 8.
  test $ac_cv_header_sys_param_h = yes &&
  test $ac_cv_header_sys_mount_h = yes &&
  AC_CHECK_HEADERS([nfs/vfs.h],
    [AC_CHECK_HEADERS([nfs/nfs_client.h])])

  statvfs_includes="\
AC_INCLUDES_DEFAULT
#include <sys/statvfs.h>
"
  statfs_includes="\
AC_INCLUDES_DEFAULT
#if HAVE_SYS_VFS_H
# include <sys/vfs.h>
#elif HAVE_SYS_MOUNT_H && HAVE_SYS_PARAM_H
# include <sys/param.h>
# include <sys/mount.h>
# if HAVE_NETINET_IN_H && HAVE_NFS_NFS_CLNT_H && HAVE_NFS_VFS_H
#  include <netinet/in.h>
#  include <nfs/nfs_clnt.h>
#  include <nfs/vfs.h>
# endif
#elif HAVE_OS_H
# include <fs_info.h>
#endif
"
  dnl Keep this long conditional in sync with the USE_STATVFS conditional
  dnl in ../src/stat.c.
  if case "$fu_cv_sys_stat_statvfs$fu_cv_sys_stat_statvfs64" in
       *yes*) ;; *) false;; esac &&
     { AC_CHECK_MEMBERS([struct statvfs.f_basetype],,, [$statvfs_includes])
       test $ac_cv_member_struct_statvfs_f_basetype = yes ||
       { AC_CHECK_MEMBERS([struct statvfs.f_fstypename],,, [$statvfs_includes])
         test $ac_cv_member_struct_statvfs_f_fstypename = yes ||
         { test $ac_cv_member_struct_statfs_f_fstypename != yes &&
           { AC_CHECK_MEMBERS([struct statvfs.f_type],,, [$statvfs_includes])
             test $ac_cv_member_struct_statvfs_f_type = yes; }; }; }; }
  then
    AC_CHECK_MEMBERS([struct statvfs.f_namemax],,, [$statvfs_includes])
    AC_COMPILE_IFELSE(
      [AC_LANG_PROGRAM(
         [$statvfs_includes],
         [static statvfs s;
          return (s.s_fsid ^ 0) == 0;])],
      [AC_DEFINE([STRUCT_STATVFS_F_FSID_IS_INTEGER], [1],
         [Define to 1 if the f_fsid member of struct statvfs is an integer.])])
  else
    AC_CHECK_MEMBERS([struct statfs.f_namelen, struct statfs.f_type,
                     struct statfs.f_frsize],,, [$statfs_includes])
    if test $ac_cv_header_OS_h != yes; then
      AC_COMPILE_IFELSE(
        [AC_LANG_PROGRAM(
           [$statfs_includes],
           [static statfs s;
            return (s.s_fsid ^ 0) == 0;])],
        [AC_DEFINE([STRUCT_STATFS_F_FSID_IS_INTEGER], [1],
           [Define to 1 if the f_fsid member of struct statfs is an integer.])])
    fi
  fi
])
