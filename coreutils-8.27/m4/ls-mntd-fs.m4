# serial 32
# How to list mounted file systems.

# Copyright (C) 1998-2004, 2006, 2009-2017 Free Software Foundation, Inc.
#
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

dnl From Jim Meyering.
dnl
dnl This is not pretty.  I've just taken the autoconf code and wrapped
dnl it in an AC_DEFUN and made some other fixes.
dnl

# Replace Autoconf's AC_FUNC_GETMNTENT to work around a bug in Autoconf
# through Autoconf 2.59.  We can remove this once we assume Autoconf 2.60
# or later.
AC_DEFUN([AC_FUNC_GETMNTENT],
[# getmntent is in the standard C library on UNICOS, in -lsun on Irix 4,
# -lseq on Dynix/PTX, -lgen on Unixware.
AC_SEARCH_LIBS([getmntent], [sun seq gen])
AC_CHECK_FUNCS([getmntent])
])

# gl_LIST_MOUNTED_FILE_SYSTEMS([ACTION-IF-FOUND[, ACTION-IF-NOT-FOUND]])
AC_DEFUN([gl_LIST_MOUNTED_FILE_SYSTEMS],
  [
AC_CHECK_FUNCS([listmntent getmntinfo])
AC_CHECK_HEADERS_ONCE([sys/param.h sys/statvfs.h])

# We must include grp.h before ucred.h on OSF V4.0, since ucred.h uses
# NGROUPS (as the array dimension for a struct member) without a definition.
AC_CHECK_HEADERS([sys/ucred.h], [], [], [#include <grp.h>])

AC_CHECK_HEADERS([sys/mount.h], [], [],
  [AC_INCLUDES_DEFAULT
   [#if HAVE_SYS_PARAM_H
     #include <sys/param.h>
    #endif]])

AC_CHECK_HEADERS([mntent.h sys/fs_types.h])
    getfsstat_includes="\
$ac_includes_default
#if HAVE_SYS_PARAM_H
# include <sys/param.h> /* needed by powerpc-apple-darwin1.3.7 */
#endif
#if HAVE_SYS_UCRED_H
# include <grp.h> /* needed for definition of NGROUPS */
# include <sys/ucred.h> /* needed by powerpc-apple-darwin1.3.7 */
#endif
#if HAVE_SYS_MOUNT_H
# include <sys/mount.h>
#endif
#if HAVE_SYS_FS_TYPES_H
# include <sys/fs_types.h> /* needed by powerpc-apple-darwin1.3.7 */
#endif
"
AC_CHECK_MEMBERS([struct fsstat.f_fstypename],,,[$getfsstat_includes])

# Determine how to get the list of mounted file systems.
ac_list_mounted_fs=

# If the getmntent function is available but not in the standard library,
# make sure LIBS contains the appropriate -l option.
AC_FUNC_GETMNTENT

# This test must precede the ones for getmntent because Unicos-9 is
# reported to have the getmntent function, but its support is incompatible
# with other getmntent implementations.

# NOTE: Normally, I wouldn't use a check for system type as I've done for
# 'CRAY' below since that goes against the whole autoconf philosophy.  But
# I think there is too great a chance that some non-Cray system has a
# function named listmntent to risk the false positive.

if test -z "$ac_list_mounted_fs"; then
  # Cray UNICOS 9
  AC_MSG_CHECKING([for listmntent of Cray/Unicos-9])
  AC_CACHE_VAL([fu_cv_sys_mounted_cray_listmntent],
    [fu_cv_sys_mounted_cray_listmntent=no
      AC_EGREP_CPP([yes],
        [#ifdef _CRAY
yes
#endif
        ], [test $ac_cv_func_listmntent = yes \
            && fu_cv_sys_mounted_cray_listmntent=yes]
      )
    ]
  )
  AC_MSG_RESULT([$fu_cv_sys_mounted_cray_listmntent])
  if test $fu_cv_sys_mounted_cray_listmntent = yes; then
    ac_list_mounted_fs=found
    AC_DEFINE([MOUNTED_LISTMNTENT], [1],
      [Define if there is a function named listmntent that can be used to
       list all mounted file systems.  (UNICOS)])
  fi
fi

if test -z "$ac_list_mounted_fs"; then
  # AIX.
  AC_MSG_CHECKING([for mntctl function and struct vmount])
  AC_CACHE_VAL([fu_cv_sys_mounted_vmount],
  [AC_PREPROC_IFELSE([AC_LANG_SOURCE([[#include <fshelp.h>]])],
    [fu_cv_sys_mounted_vmount=yes],
    [fu_cv_sys_mounted_vmount=no])])
  AC_MSG_RESULT([$fu_cv_sys_mounted_vmount])
  if test $fu_cv_sys_mounted_vmount = yes; then
    ac_list_mounted_fs=found
    AC_DEFINE([MOUNTED_VMOUNT], [1],
        [Define if there is a function named mntctl that can be used to read
         the list of mounted file systems, and there is a system header file
         that declares 'struct vmount'.  (AIX)])
  fi
fi

if test $ac_cv_func_getmntent = yes; then

  # This system has the getmntent function.
  # Determine whether it's the one-argument variant or the two-argument one.

  if test -z "$ac_list_mounted_fs"; then
    # GNU/Linux, 4.3BSD, SunOS, HP-UX, Dynix, Irix
    AC_MSG_CHECKING([for one-argument getmntent function])
    AC_CACHE_VAL([fu_cv_sys_mounted_getmntent1],
                 [AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
/* SunOS 4.1.x /usr/include/mntent.h needs this for FILE */
#include <stdio.h>

#include <mntent.h>
#if !defined MOUNTED
# if defined _PATH_MOUNTED      /* GNU libc  */
#  define MOUNTED _PATH_MOUNTED
# endif
# if defined MNT_MNTTAB /* HP-UX.  */
#  define MOUNTED MNT_MNTTAB
# endif
# if defined MNTTABNAME /* Dynix.  */
#  define MOUNTED MNTTABNAME
# endif
#endif
]],
                      [[ struct mntent *mnt = 0; char *table = MOUNTED;
                         if (sizeof mnt && sizeof table) return 0;]])],
                    [fu_cv_sys_mounted_getmntent1=yes],
                    [fu_cv_sys_mounted_getmntent1=no])])
    AC_MSG_RESULT([$fu_cv_sys_mounted_getmntent1])
    if test $fu_cv_sys_mounted_getmntent1 = yes; then
      ac_list_mounted_fs=found
      AC_DEFINE([MOUNTED_GETMNTENT1], [1],
        [Define if there is a function named getmntent for reading the list
         of mounted file systems, and that function takes a single argument.
         (4.3BSD, SunOS, HP-UX, Dynix, Irix)])
      AC_CHECK_FUNCS([hasmntopt])
    fi
  fi

  if test -z "$ac_list_mounted_fs"; then
    # SVR4
    AC_MSG_CHECKING([for two-argument getmntent function])
    AC_CACHE_VAL([fu_cv_sys_mounted_getmntent2],
    [AC_EGREP_HEADER([getmntent], [sys/mnttab.h],
      fu_cv_sys_mounted_getmntent2=yes,
      fu_cv_sys_mounted_getmntent2=no)])
    AC_MSG_RESULT([$fu_cv_sys_mounted_getmntent2])
    if test $fu_cv_sys_mounted_getmntent2 = yes; then
      ac_list_mounted_fs=found
      AC_DEFINE([MOUNTED_GETMNTENT2], [1],
        [Define if there is a function named getmntent for reading the list of
         mounted file systems, and that function takes two arguments.  (SVR4)])
      AC_CHECK_FUNCS([hasmntopt])
    fi
  fi

fi

if test -z "$ac_list_mounted_fs"; then
  # DEC Alpha running OSF/1, and Apple Darwin 1.3.
  # powerpc-apple-darwin1.3.7 needs sys/param.h sys/ucred.h sys/fs_types.h

  AC_MSG_CHECKING([for getfsstat function])
  AC_CACHE_VAL([fu_cv_sys_mounted_getfsstat],
  [AC_LINK_IFELSE([AC_LANG_PROGRAM([[
#include <sys/types.h>
#if HAVE_STRUCT_FSSTAT_F_FSTYPENAME
# define FS_TYPE(Ent) ((Ent).f_fstypename)
#else
# define FS_TYPE(Ent) mnt_names[(Ent).f_type]
#endif
$getfsstat_includes]]
,
      [[struct statfs *stats;
        int numsys = getfsstat ((struct statfs *)0, 0L, MNT_WAIT);
        char *t = FS_TYPE (*stats); ]])],
    [fu_cv_sys_mounted_getfsstat=yes],
    [fu_cv_sys_mounted_getfsstat=no])])
  AC_MSG_RESULT([$fu_cv_sys_mounted_getfsstat])
  if test $fu_cv_sys_mounted_getfsstat = yes; then
    ac_list_mounted_fs=found
    AC_DEFINE([MOUNTED_GETFSSTAT], [1],
              [Define if there is a function named getfsstat for reading the
               list of mounted file systems.  (DEC Alpha running OSF/1)])
  fi
fi

if test -z "$ac_list_mounted_fs"; then
  # SVR3
  AC_MSG_CHECKING([for FIXME existence of three headers])
  AC_CACHE_VAL([fu_cv_sys_mounted_fread_fstyp],
    [AC_PREPROC_IFELSE([AC_LANG_SOURCE([[
#include <sys/statfs.h>
#include <sys/fstyp.h>
#include <mnttab.h>]])],
                       [fu_cv_sys_mounted_fread_fstyp=yes],
                       [fu_cv_sys_mounted_fread_fstyp=no])])
  AC_MSG_RESULT([$fu_cv_sys_mounted_fread_fstyp])
  if test $fu_cv_sys_mounted_fread_fstyp = yes; then
    ac_list_mounted_fs=found
    AC_DEFINE([MOUNTED_FREAD_FSTYP], [1],
      [Define if (like SVR2) there is no specific function for reading the
       list of mounted file systems, and your system has these header files:
       <sys/fstyp.h> and <sys/statfs.h>.  (SVR3)])
  fi
fi

if test -z "$ac_list_mounted_fs"; then
  # 4.4BSD and DEC OSF/1.
  AC_MSG_CHECKING([for getmntinfo function])
  AC_CACHE_VAL([fu_cv_sys_mounted_getmntinfo],
    [
      test "$ac_cv_func_getmntinfo" = yes \
          && fu_cv_sys_mounted_getmntinfo=yes \
          || fu_cv_sys_mounted_getmntinfo=no
    ])
  AC_MSG_RESULT([$fu_cv_sys_mounted_getmntinfo])
  if test $fu_cv_sys_mounted_getmntinfo = yes; then
    AC_MSG_CHECKING([whether getmntinfo returns statvfs structures])
    AC_CACHE_VAL([fu_cv_sys_mounted_getmntinfo2],
      [
        AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
#if HAVE_SYS_PARAM_H
# include <sys/param.h>
#endif
#include <sys/types.h>
#if HAVE_SYS_MOUNT_H
# include <sys/mount.h>
#endif
#if HAVE_SYS_STATVFS_H
# include <sys/statvfs.h>
#endif
extern
#ifdef __cplusplus
"C"
#endif
int getmntinfo (struct statfs **, int);
            ]], [])],
          [fu_cv_sys_mounted_getmntinfo2=no],
          [fu_cv_sys_mounted_getmntinfo2=yes])
      ])
    AC_MSG_RESULT([$fu_cv_sys_mounted_getmntinfo2])
    if test $fu_cv_sys_mounted_getmntinfo2 = no; then
      ac_list_mounted_fs=found
      AC_DEFINE([MOUNTED_GETMNTINFO], [1],
                [Define if there is a function named getmntinfo for reading the
                 list of mounted file systems and it returns an array of
                 'struct statfs'.  (4.4BSD, Darwin)])
    else
      ac_list_mounted_fs=found
      AC_DEFINE([MOUNTED_GETMNTINFO2], [1],
                [Define if there is a function named getmntinfo for reading the
                 list of mounted file systems and it returns an array of
                 'struct statvfs'.  (NetBSD 3.0)])
    fi
  fi
fi

if test -z "$ac_list_mounted_fs"; then
  # Ultrix
  AC_MSG_CHECKING([for getmnt function])
  AC_CACHE_VAL([fu_cv_sys_mounted_getmnt],
    [AC_PREPROC_IFELSE([AC_LANG_SOURCE([[
#include <sys/fs_types.h>
#include <sys/mount.h>]])],
                       [fu_cv_sys_mounted_getmnt=yes],
                       [fu_cv_sys_mounted_getmnt=no])])
  AC_MSG_RESULT([$fu_cv_sys_mounted_getmnt])
  if test $fu_cv_sys_mounted_getmnt = yes; then
    ac_list_mounted_fs=found
    AC_DEFINE([MOUNTED_GETMNT], [1],
      [Define if there is a function named getmnt for reading the list of
       mounted file systems.  (Ultrix)])
  fi
fi

if test -z "$ac_list_mounted_fs"; then
  # BeOS
  AC_CHECK_FUNCS([next_dev fs_stat_dev])
  AC_CHECK_HEADERS([fs_info.h])
  AC_MSG_CHECKING([for BEOS mounted file system support functions])
  if test $ac_cv_header_fs_info_h = yes \
      && test $ac_cv_func_next_dev = yes \
        && test $ac_cv_func_fs_stat_dev = yes; then
    fu_result=yes
  else
    fu_result=no
  fi
  AC_MSG_RESULT([$fu_result])
  if test $fu_result = yes; then
    ac_list_mounted_fs=found
    AC_DEFINE([MOUNTED_FS_STAT_DEV], [1],
      [Define if there are functions named next_dev and fs_stat_dev for
       reading the list of mounted file systems.  (BeOS)])
  fi
fi

if test -z "$ac_list_mounted_fs"; then
  # SVR2
  AC_MSG_CHECKING([whether it is possible to resort to fread on /etc/mnttab])
  AC_CACHE_VAL([fu_cv_sys_mounted_fread],
    [AC_PREPROC_IFELSE([AC_LANG_SOURCE([[#include <mnttab.h>]])],
                       [fu_cv_sys_mounted_fread=yes],
                       [fu_cv_sys_mounted_fread=no])])
  AC_MSG_RESULT([$fu_cv_sys_mounted_fread])
  if test $fu_cv_sys_mounted_fread = yes; then
    ac_list_mounted_fs=found
    AC_DEFINE([MOUNTED_FREAD], [1],
              [Define if there is no specific function for reading the list of
               mounted file systems.  fread will be used to read /etc/mnttab.
               (SVR2) ])
  fi
fi

if test -z "$ac_list_mounted_fs"; then
  # Interix / BSD alike statvfs
  # the code is really interix specific, so make sure, we're on it.
  case "$host" in
  *-interix*)
    AC_CHECK_FUNCS([statvfs])
    if test $ac_cv_func_statvfs = yes; then
      ac_list_mounted_fs=found
      AC_DEFINE([MOUNTED_INTERIX_STATVFS], [1],
                [Define if we are on interix, and ought to use statvfs plus
                 some special knowledge on where mounted file systems can be
                 found. (Interix)])
    fi
    ;;
  esac
fi

if test -z "$ac_list_mounted_fs"; then
  AC_MSG_ERROR([could not determine how to read list of mounted file systems])
  # FIXME -- no need to abort building the whole package
  # Can't build mountlist.c or anything that needs its functions
fi

AS_IF([test $ac_list_mounted_fs = found], [$1], [$2])

  ])
