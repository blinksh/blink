# serial 19
dnl Run a program to determine whether link(2) follows symlinks.
dnl Set LINK_FOLLOWS_SYMLINKS accordingly.

# Copyright (C) 1999-2001, 2004-2006, 2009-2017 Free Software Foundation, Inc.
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

dnl This macro can be used to emulate POSIX linkat.  If
dnl LINK_FOLLOWS_SYMLINKS is 0, link matches linkat(,0), and
dnl linkat(,AT_SYMLINK_FOLLOW) requires a readlink. If it is 1,
dnl link matches linkat(,AT_SYMLINK_FOLLOW), and there is no way
dnl to do linkat(,0) on symlinks (on all other file types,
dnl link() is sufficient).  If it is -1, use a Solaris specific
dnl runtime test.  If it is -2, use a generic runtime test.
AC_DEFUN([gl_FUNC_LINK_FOLLOWS_SYMLINK],
[dnl
  AC_REQUIRE([AC_CANONICAL_HOST]) dnl for cross-compiles
  AC_CHECK_FUNCS_ONCE([readlink])
  dnl Mingw lacks link, although gnulib provides a good replacement.
  dnl However, it also lacks symlink, so there's nothing to test in
  dnl the first place, and no reason to need to distinguish between
  dnl linkat variants.  So, we set LINK_FOLLOWS_SYMLINKS to 0.
  gl_link_follows_symlinks=0 # assume GNU behavior
  if test $ac_cv_func_readlink = yes; then
    dnl Solaris has an __xpg4 variable in libc, and it determines the
    dnl behaviour of link(): It dereferences a symlink if and only if
    dnl __xpg4 != 0.
    AC_CACHE_CHECK([for __xpg4], [gl_cv_have___xpg4],
      [AC_LINK_IFELSE(
         [AC_LANG_PROGRAM(
            [[extern int __xpg4;]],
            [[return __xpg4;]])],
         [gl_cv_have___xpg4=yes],
         [gl_cv_have___xpg4=no])
      ])
    if test $gl_cv_have___xpg4 = yes; then
      gl_link_follows_symlinks=-1
    else
      AC_CACHE_CHECK([whether link(2) dereferences a symlink],
                     [gl_cv_func_link_follows_symlink],
        [
         # Create a regular file.
         echo > conftest.file
         AC_RUN_IFELSE(
           [AC_LANG_SOURCE([[
#       include <sys/types.h>
#       include <sys/stat.h>
#       include <unistd.h>
#       include <stdlib.h>

#       define SAME_INODE(Stat_buf_1, Stat_buf_2) \
          ((Stat_buf_1).st_ino == (Stat_buf_2).st_ino \
           && (Stat_buf_1).st_dev == (Stat_buf_2).st_dev)

        int
        main ()
        {
          const char *file = "conftest.file";
          const char *sym = "conftest.sym";
          const char *hard = "conftest.hard";
          struct stat sb_file, sb_hard;

          /* Create a symlink to the regular file. */
          if (symlink (file, sym))
            return 2;

          /* Create a hard link to that symlink.  */
          if (link (sym, hard))
            return 3;

          if (lstat (hard, &sb_hard))
            return 4;
          if (lstat (file, &sb_file))
            return 5;

          /* If the dev/inode of hard and file are the same, then
             the link call followed the symlink.  */
          return SAME_INODE (sb_hard, sb_file) ? 1 : 0;
        }
           ]])],
           [gl_cv_func_link_follows_symlink=no], dnl GNU behavior
           [gl_cv_func_link_follows_symlink=yes], dnl Followed link/compile failed
           [dnl We're cross compiling.
            dnl The past results are "yes" on Mac OS X, FreeBSD, NetBSD,
            dnl OpenBSD, Minix, AIX, HP-UX, OSF/1, and "no" on Linux, Cygwin.
            case "$host_os" in
                           # On glibc/Linux we know the result.
              linux*-gnu*) gl_cv_func_link_follows_symlink="guessing no" ;;
                           # Otherwise, we don't know.
              *)           gl_cv_func_link_follows_symlink=unknown ;;
            esac
           ])
         rm -f conftest.file conftest.sym conftest.hard
        ])
      case "$gl_cv_func_link_follows_symlink" in
        *yes) gl_link_follows_symlinks=1 ;;
        *no) ;; # already defaulted to 0
        *) gl_link_follows_symlinks=-2 ;;
      esac
    fi
  fi
  AC_DEFINE_UNQUOTED([LINK_FOLLOWS_SYMLINKS], [$gl_link_follows_symlinks],
    [Define to 1 if 'link(2)' dereferences symbolic links, 0 if it
     creates hard links to symlinks, -1 if it depends on the variable __xpg4,
     and -2 if unknown.])
])
