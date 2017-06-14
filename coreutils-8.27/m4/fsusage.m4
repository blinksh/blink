# serial 31
# Obtaining file system usage information.

# Copyright (C) 1997-1998, 2000-2001, 2003-2017 Free Software Foundation, Inc.
#
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

# Written by Jim Meyering.

AC_DEFUN([gl_FSUSAGE],
[
  AC_CHECK_HEADERS_ONCE([sys/param.h])
  AC_CHECK_HEADERS_ONCE([sys/vfs.h sys/fs_types.h])
  AC_CHECK_HEADERS([sys/mount.h], [], [],
    [AC_INCLUDES_DEFAULT
     [#if HAVE_SYS_PARAM_H
       #include <sys/param.h>
      #endif]])
  gl_FILE_SYSTEM_USAGE([gl_cv_fs_space=yes], [gl_cv_fs_space=no])
])

# Try to determine how a program can obtain file system usage information.
# If successful, define the appropriate symbol (see fsusage.c) and
# execute ACTION-IF-FOUND.  Otherwise, execute ACTION-IF-NOT-FOUND.
#
# gl_FILE_SYSTEM_USAGE([ACTION-IF-FOUND[, ACTION-IF-NOT-FOUND]])

AC_DEFUN([gl_FILE_SYSTEM_USAGE],
[
dnl Enable large-file support. This has the effect of changing the size
dnl of field f_blocks in 'struct statvfs' from 32 bit to 64 bit on
dnl glibc/Hurd, HP-UX 11, Solaris (32-bit mode). It also changes the size
dnl of field f_blocks in 'struct statfs' from 32 bit to 64 bit on
dnl Mac OS X >= 10.5 (32-bit mode).
AC_REQUIRE([AC_SYS_LARGEFILE])

AC_MSG_CHECKING([how to get file system space usage])
ac_fsusage_space=no

# Perform only the link test since it seems there are no variants of the
# statvfs function.  This check is more than just AC_CHECK_FUNCS([statvfs])
# because that got a false positive on SCO OSR5.  Adding the declaration
# of a 'struct statvfs' causes this test to fail (as it should) on such
# systems.  That system is reported to work fine with STAT_STATFS4 which
# is what it gets when this test fails.
if test $ac_fsusage_space = no; then
  # glibc/{Hurd,kFreeBSD}, FreeBSD >= 5.0, NetBSD >= 3.0,
  # OpenBSD >= 4.4, AIX, HP-UX, IRIX, Solaris, Cygwin, Interix, BeOS.
  AC_CACHE_CHECK([for statvfs function (SVR4)], [fu_cv_sys_stat_statvfs],
                 [AC_LINK_IFELSE([AC_LANG_PROGRAM([[#include <sys/types.h>
#ifdef __osf__
"Do not use Tru64's statvfs implementation"
#endif

#include <sys/statvfs.h>

struct statvfs fsd;

#if defined __APPLE__ && defined __MACH__
#include <limits.h>
/* On Mac OS X >= 10.5, f_blocks in 'struct statvfs' is a 32-bit quantity;
   that commonly limits file systems to 4 TiB.  Whereas f_blocks in
   'struct statfs' is a 64-bit type, thanks to the large-file support
   that was enabled above.  In this case, don't use statvfs(); use statfs()
   instead.  */
int check_f_blocks_size[sizeof fsd.f_blocks * CHAR_BIT <= 32 ? -1 : 1];
#endif
]],
                                    [[statvfs (0, &fsd);]])],
                                 [fu_cv_sys_stat_statvfs=yes],
                                 [fu_cv_sys_stat_statvfs=no])])
  if test $fu_cv_sys_stat_statvfs = yes; then
    ac_fsusage_space=yes
    # AIX >= 5.2 has statvfs64 that has a wider f_blocks field than statvfs.
    # glibc, HP-UX, IRIX, Solaris have statvfs64 as well, but on these systems
    # statvfs with large-file support is already equivalent to statvfs64.
    AC_CACHE_CHECK([whether to use statvfs64],
      [fu_cv_sys_stat_statvfs64],
      [AC_LINK_IFELSE(
         [AC_LANG_PROGRAM(
            [[#include <sys/types.h>
              #include <sys/statvfs.h>
              struct statvfs64 fsd;
              int check_f_blocks_larger_in_statvfs64
                [sizeof (((struct statvfs64 *) 0)->f_blocks)
                 > sizeof (((struct statvfs *) 0)->f_blocks)
                 ? 1 : -1];
            ]],
            [[statvfs64 (0, &fsd);]])],
         [fu_cv_sys_stat_statvfs64=yes],
         [fu_cv_sys_stat_statvfs64=no])
      ])
    if test $fu_cv_sys_stat_statvfs64 = yes; then
      AC_DEFINE([STAT_STATVFS64], [1],
                [  Define if statvfs64 should be preferred over statvfs.])
    else
      AC_DEFINE([STAT_STATVFS], [1],
                [  Define if there is a function named statvfs.  (SVR4)])
    fi
  fi
fi

# Check for this unconditionally so we have a
# good fallback on glibc/Linux > 2.6 < 2.6.36
AC_MSG_CHECKING([for two-argument statfs with statfs.f_frsize member])
AC_CACHE_VAL([fu_cv_sys_stat_statfs2_frsize],
[AC_RUN_IFELSE([AC_LANG_SOURCE([[
#ifdef HAVE_SYS_PARAM_H
#include <sys/param.h>
#endif
#ifdef HAVE_SYS_MOUNT_H
#include <sys/mount.h>
#endif
#ifdef HAVE_SYS_VFS_H
#include <sys/vfs.h>
#endif
  int
  main ()
  {
  struct statfs fsd;
  fsd.f_frsize = 0;
  return statfs (".", &fsd) != 0;
  }]])],
  [fu_cv_sys_stat_statfs2_frsize=yes],
  [fu_cv_sys_stat_statfs2_frsize=no],
  [fu_cv_sys_stat_statfs2_frsize=no])])
AC_MSG_RESULT([$fu_cv_sys_stat_statfs2_frsize])
if test $fu_cv_sys_stat_statfs2_frsize = yes; then
    ac_fsusage_space=yes
    AC_DEFINE([STAT_STATFS2_FRSIZE], [1],
[  Define if statfs takes 2 args and struct statfs has a field named f_frsize.
   (glibc/Linux > 2.6)])
fi

if test $ac_fsusage_space = no; then
  # DEC Alpha running OSF/1
  AC_MSG_CHECKING([for 3-argument statfs function (DEC OSF/1)])
  AC_CACHE_VAL([fu_cv_sys_stat_statfs3_osf1],
  [AC_RUN_IFELSE([AC_LANG_SOURCE([[
#include <sys/param.h>
#include <sys/types.h>
#include <sys/mount.h>
  int
  main ()
  {
    struct statfs fsd;
    fsd.f_fsize = 0;
    return statfs (".", &fsd, sizeof (struct statfs)) != 0;
  }]])],
    [fu_cv_sys_stat_statfs3_osf1=yes],
    [fu_cv_sys_stat_statfs3_osf1=no],
    [fu_cv_sys_stat_statfs3_osf1=no])])
  AC_MSG_RESULT([$fu_cv_sys_stat_statfs3_osf1])
  if test $fu_cv_sys_stat_statfs3_osf1 = yes; then
    ac_fsusage_space=yes
    AC_DEFINE([STAT_STATFS3_OSF1], [1],
              [   Define if  statfs takes 3 args.  (DEC Alpha running OSF/1)])
  fi
fi

if test $ac_fsusage_space = no; then
  # glibc/Linux, Mac OS X, FreeBSD < 5.0, NetBSD < 3.0, OpenBSD < 4.4.
  # (glibc/{Hurd,kFreeBSD}, FreeBSD >= 5.0, NetBSD >= 3.0,
  # OpenBSD >= 4.4, AIX, HP-UX, OSF/1, Cygwin already handled above.)
  # (On IRIX you need to include <sys/statfs.h>, not only <sys/mount.h> and
  # <sys/vfs.h>.)
  # (On Solaris, statfs has 4 arguments.)
  AC_MSG_CHECKING([for two-argument statfs with statfs.f_bsize dnl
member (AIX, 4.3BSD)])
  AC_CACHE_VAL([fu_cv_sys_stat_statfs2_bsize],
  [AC_RUN_IFELSE([AC_LANG_SOURCE([[
#ifdef HAVE_SYS_PARAM_H
#include <sys/param.h>
#endif
#ifdef HAVE_SYS_MOUNT_H
#include <sys/mount.h>
#endif
#ifdef HAVE_SYS_VFS_H
#include <sys/vfs.h>
#endif
  int
  main ()
  {
  struct statfs fsd;
  fsd.f_bsize = 0;
  return statfs (".", &fsd) != 0;
  }]])],
    [fu_cv_sys_stat_statfs2_bsize=yes],
    [fu_cv_sys_stat_statfs2_bsize=no],
    [fu_cv_sys_stat_statfs2_bsize=no])])
  AC_MSG_RESULT([$fu_cv_sys_stat_statfs2_bsize])
  if test $fu_cv_sys_stat_statfs2_bsize = yes; then
    ac_fsusage_space=yes
    AC_DEFINE([STAT_STATFS2_BSIZE], [1],
[  Define if statfs takes 2 args and struct statfs has a field named f_bsize.
   (4.3BSD, SunOS 4, HP-UX, AIX PS/2)])
  fi
fi

if test $ac_fsusage_space = no; then
  # SVR3
  # (Solaris already handled above.)
  AC_MSG_CHECKING([for four-argument statfs (AIX-3.2.5, SVR3)])
  AC_CACHE_VAL([fu_cv_sys_stat_statfs4],
  [AC_RUN_IFELSE([AC_LANG_SOURCE([[
#include <sys/types.h>
#include <sys/statfs.h>
  int
  main ()
  {
  struct statfs fsd;
  return statfs (".", &fsd, sizeof fsd, 0) != 0;
  }]])],
    [fu_cv_sys_stat_statfs4=yes],
    [fu_cv_sys_stat_statfs4=no],
    [fu_cv_sys_stat_statfs4=no])])
  AC_MSG_RESULT([$fu_cv_sys_stat_statfs4])
  if test $fu_cv_sys_stat_statfs4 = yes; then
    ac_fsusage_space=yes
    AC_DEFINE([STAT_STATFS4], [1],
      [  Define if statfs takes 4 args.  (SVR3, Dynix, old Irix, old AIX, Dolphin)])
  fi
fi

if test $ac_fsusage_space = no; then
  # 4.4BSD and older NetBSD
  # (OSF/1 already handled above.)
  # (On AIX, you need to include <sys/statfs.h>, not only <sys/mount.h>.)
  # (On Solaris, statfs has 4 arguments and 'struct statfs' is not declared in
  # <sys/mount.h>.)
  AC_MSG_CHECKING([for two-argument statfs with statfs.f_fsize dnl
member (4.4BSD and NetBSD)])
  AC_CACHE_VAL([fu_cv_sys_stat_statfs2_fsize],
  [AC_RUN_IFELSE([AC_LANG_SOURCE([[
#include <sys/types.h>
#ifdef HAVE_SYS_PARAM_H
#include <sys/param.h>
#endif
#ifdef HAVE_SYS_MOUNT_H
#include <sys/mount.h>
#endif
  int
  main ()
  {
  struct statfs fsd;
  fsd.f_fsize = 0;
  return statfs (".", &fsd) != 0;
  }]])],
    [fu_cv_sys_stat_statfs2_fsize=yes],
    [fu_cv_sys_stat_statfs2_fsize=no],
    [fu_cv_sys_stat_statfs2_fsize=no])])
  AC_MSG_RESULT([$fu_cv_sys_stat_statfs2_fsize])
  if test $fu_cv_sys_stat_statfs2_fsize = yes; then
    ac_fsusage_space=yes
    AC_DEFINE([STAT_STATFS2_FSIZE], [1],
[  Define if statfs takes 2 args and struct statfs has a field named f_fsize.
   (4.4BSD, NetBSD)])
  fi
fi

if test $ac_fsusage_space = no; then
  # Ultrix
  AC_MSG_CHECKING([for two-argument statfs with struct fs_data (Ultrix)])
  AC_CACHE_VAL([fu_cv_sys_stat_fs_data],
  [AC_RUN_IFELSE([AC_LANG_SOURCE([[
#include <sys/types.h>
#ifdef HAVE_SYS_PARAM_H
#include <sys/param.h>
#endif
#ifdef HAVE_SYS_MOUNT_H
#include <sys/mount.h>
#endif
#ifdef HAVE_SYS_FS_TYPES_H
#include <sys/fs_types.h>
#endif
  int
  main ()
  {
  struct fs_data fsd;
  /* Ultrix's statfs returns 1 for success,
     0 for not mounted, -1 for failure.  */
  return statfs (".", &fsd) != 1;
  }]])],
    [fu_cv_sys_stat_fs_data=yes],
    [fu_cv_sys_stat_fs_data=no],
    [fu_cv_sys_stat_fs_data=no])])
  AC_MSG_RESULT([$fu_cv_sys_stat_fs_data])
  if test $fu_cv_sys_stat_fs_data = yes; then
    ac_fsusage_space=yes
    AC_DEFINE([STAT_STATFS2_FS_DATA], [1],
[  Define if statfs takes 2 args and the second argument has
   type struct fs_data.  (Ultrix)])
  fi
fi

if test $ac_fsusage_space = no; then
  # SVR2
  # (AIX, HP-UX, OSF/1 already handled above.)
  AC_PREPROC_IFELSE([AC_LANG_SOURCE([[#include <sys/filsys.h>
        ]])],
    [AC_DEFINE([STAT_READ_FILSYS], [1],
      [Define if there is no specific function for reading file systems usage
       information and you have the <sys/filsys.h> header file.  (SVR2)])
     ac_fsusage_space=yes])
fi

AS_IF([test $ac_fsusage_space = yes], [$1], [$2])

])


# Check for SunOS statfs brokenness wrt partitions 2GB and larger.
# If <sys/vfs.h> exists and struct statfs has a member named f_spare,
# enable the work-around code in fsusage.c.
AC_DEFUN([gl_STATFS_TRUNCATES],
[
  AC_MSG_CHECKING([for statfs that truncates block counts])
  AC_CACHE_VAL([fu_cv_sys_truncating_statfs],
  [AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
#if !defined(sun) && !defined(__sun)
choke -- this is a workaround for a Sun-specific problem
#endif
#include <sys/types.h>
#include <sys/vfs.h>]],
      [[struct statfs t; long c = *(t.f_spare);
        if (c) return 0;]])],
    [fu_cv_sys_truncating_statfs=yes],
    [fu_cv_sys_truncating_statfs=no])])
  if test $fu_cv_sys_truncating_statfs = yes; then
    AC_DEFINE([STATFS_TRUNCATES_BLOCK_COUNTS], [1],
      [Define if the block counts reported by statfs may be truncated to 2GB
       and the correct values may be stored in the f_spare array.
       (SunOS 4.1.2, 4.1.3, and 4.1.3_U1 are reported to have this problem.
       SunOS 4.1.1 seems not to be affected.)])
  fi
  AC_MSG_RESULT([$fu_cv_sys_truncating_statfs])
])


# Prerequisites of lib/fsusage.c not done by gl_FILE_SYSTEM_USAGE.
AC_DEFUN([gl_PREREQ_FSUSAGE_EXTRA],
[
  AC_CHECK_HEADERS([dustat.h sys/fs/s5param.h sys/filsys.h sys/statfs.h])
  gl_STATFS_TRUNCATES
])
