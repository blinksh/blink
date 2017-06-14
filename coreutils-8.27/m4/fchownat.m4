# fchownat.m4 serial 1
dnl Copyright (C) 2004-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

# Written by Jim Meyering.

# If we have the fchownat function, and it has the bug (in glibc-2.4)
# that it dereferences symlinks even with AT_SYMLINK_NOFOLLOW, then
# use the replacement function.
# Also if the fchownat function, like chown, has the trailing slash bug,
# use the replacement function.
# Also use the replacement function if fchownat is simply not available.
AC_DEFUN([gl_FUNC_FCHOWNAT],
[
  AC_REQUIRE([gl_UNISTD_H_DEFAULTS])
  AC_REQUIRE([gl_USE_SYSTEM_EXTENSIONS])
  AC_REQUIRE([gl_FUNC_CHOWN])
  AC_CHECK_FUNC([fchownat],
    [gl_FUNC_FCHOWNAT_DEREF_BUG(
       [REPLACE_FCHOWNAT=1
        AC_DEFINE([FCHOWNAT_NOFOLLOW_BUG], [1],
                  [Define to 1 if your platform has fchownat, but it cannot
                   perform lchown tasks.])
       ])
     gl_FUNC_FCHOWNAT_EMPTY_FILENAME_BUG(
       [REPLACE_FCHOWNAT=1
        AC_DEFINE([FCHOWNAT_EMPTY_FILENAME_BUG], [1],
                  [Define to 1 if your platform has fchownat, but it does
                   not reject an empty file name.])
       ])
     if test $REPLACE_CHOWN = 1; then
       REPLACE_FCHOWNAT=1
     fi],
    [HAVE_FCHOWNAT=0])
])

# gl_FUNC_FCHOWNAT_DEREF_BUG([ACTION-IF-BUGGY[, ACTION-IF-NOT_BUGGY]])
AC_DEFUN([gl_FUNC_FCHOWNAT_DEREF_BUG],
[
  dnl Persuade glibc's <unistd.h> to declare fchownat().
  AC_REQUIRE([gl_USE_SYSTEM_EXTENSIONS])

  AC_CACHE_CHECK([whether fchownat works with AT_SYMLINK_NOFOLLOW],
    gl_cv_func_fchownat_nofollow_works,
    [
     gl_dangle=conftest.dangle
     # Remove any remnants of a previous test.
     rm -f $gl_dangle
     # Arrange for deletion of the temporary file this test creates.
     ac_clean_files="$ac_clean_files $gl_dangle"
     ln -s conftest.no-such $gl_dangle
     AC_RUN_IFELSE(
       [AC_LANG_SOURCE(
          [[
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/types.h>
int
main ()
{
  return (fchownat (AT_FDCWD, "$gl_dangle", -1, getgid (),
                    AT_SYMLINK_NOFOLLOW) != 0
          && errno == ENOENT);
}
          ]])],
    [gl_cv_func_fchownat_nofollow_works=yes],
    [gl_cv_func_fchownat_nofollow_works=no],
    [gl_cv_func_fchownat_nofollow_works=no],
    )
  ])
  AS_IF([test $gl_cv_func_fchownat_nofollow_works = no], [$1], [$2])
])

# gl_FUNC_FCHOWNAT_EMPTY_FILENAME_BUG([ACTION-IF-BUGGY[, ACTION-IF-NOT_BUGGY]])
AC_DEFUN([gl_FUNC_FCHOWNAT_EMPTY_FILENAME_BUG],
[
  dnl Persuade glibc's <unistd.h> to declare fchownat().
  AC_REQUIRE([gl_USE_SYSTEM_EXTENSIONS])

  AC_CACHE_CHECK([whether fchownat works with an empty file name],
    [gl_cv_func_fchownat_empty_filename_works],
    [AC_RUN_IFELSE(
       [AC_LANG_PROGRAM(
          [[#include <unistd.h>
            #include <fcntl.h>
          ]],
          [[int fd;
            int ret;
            if (mkdir ("conftestdir", 0700) < 0)
              return 2;
            fd = open ("conftestdir", O_RDONLY);
            if (fd < 0)
              return 3;
            ret = fchownat (fd, "", -1, -1, 0);
            close (fd);
            rmdir ("conftestdir");
            return ret == 0;
          ]])],
       [gl_cv_func_fchownat_empty_filename_works=yes],
       [gl_cv_func_fchownat_empty_filename_works=no],
       [gl_cv_func_fchownat_empty_filename_works="guessing no"])
    ])
  AS_IF([test "$gl_cv_func_fchownat_empty_filename_works" != yes], [$1], [$2])
])
