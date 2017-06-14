#serial 23

# Copyright (C) 2001, 2003-2007, 2009-2017 Free Software Foundation, Inc.
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

# On some hosts (e.g., HP-UX 10.20, SunOS 4.1.4, Solaris 2.5.1), mkstemp has a
# silly limit that it can create no more than 26 files from a given template.
# Other systems lack mkstemp altogether.
# On OSF1/Tru64 V4.0F, the system-provided mkstemp function can create
# only 32 files per process.
# On some hosts, mkstemp creates files with mode 0666, which is a security
# problem and a violation of POSIX 2008.
# On systems like the above, arrange to use the replacement function.
AC_DEFUN([gl_FUNC_MKSTEMP],
[
  AC_REQUIRE([gl_STDLIB_H_DEFAULTS])
  AC_REQUIRE([AC_CANONICAL_HOST]) dnl for cross-compiles

  AC_CHECK_FUNCS_ONCE([mkstemp])
  if test $ac_cv_func_mkstemp = yes; then
    AC_CACHE_CHECK([for working mkstemp],
      [gl_cv_func_working_mkstemp],
      [
        mkdir conftest.mkstemp
        AC_RUN_IFELSE(
          [AC_LANG_PROGRAM(
            [AC_INCLUDES_DEFAULT],
            [[int result = 0;
              int i;
              off_t large = (off_t) 4294967295u;
              if (large < 0)
                large = 2147483647;
              umask (0);
              for (i = 0; i < 70; i++)
                {
                  char templ[] = "conftest.mkstemp/coXXXXXX";
                  int (*mkstemp_function) (char *) = mkstemp;
                  int fd = mkstemp_function (templ);
                  if (fd < 0)
                    result |= 1;
                  else
                    {
                      struct stat st;
                      if (lseek (fd, large, SEEK_SET) != large)
                        result |= 2;
                      if (fstat (fd, &st) < 0)
                        result |= 4;
                      else if (st.st_mode & 0077)
                        result |= 8;
                      if (close (fd))
                        result |= 16;
                    }
                }
              return result;]])],
          [gl_cv_func_working_mkstemp=yes],
          [gl_cv_func_working_mkstemp=no],
          [case "$host_os" in
                     # Guess yes on glibc systems.
             *-gnu*) gl_cv_func_working_mkstemp="guessing yes" ;;
                     # If we don't know, assume the worst.
             *)      gl_cv_func_working_mkstemp="guessing no" ;;
           esac
          ])
        rm -rf conftest.mkstemp
      ])
    case "$gl_cv_func_working_mkstemp" in
      *yes) ;;
      *)
        REPLACE_MKSTEMP=1
        ;;
    esac
  else
    HAVE_MKSTEMP=0
  fi
])

# Prerequisites of lib/mkstemp.c.
AC_DEFUN([gl_PREREQ_MKSTEMP],
[
])
