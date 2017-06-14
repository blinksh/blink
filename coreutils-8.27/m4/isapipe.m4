# Test whether a file descriptor is a pipe.

dnl Copyright (C) 2006, 2009-2017 Free Software Foundation, Inc.

dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

dnl Written by Paul Eggert.

AC_DEFUN([gl_ISAPIPE],
[
  # OpenVMS has isapipe already, so check for it.
  AC_CHECK_FUNCS([isapipe])
  if test $ac_cv_func_isapipe = yes; then
    HAVE_ISAPIPE=1
  else
    HAVE_ISAPIPE=0
  fi
])

# Prerequisites of lib/isapipe.c.
AC_DEFUN([gl_PREREQ_ISAPIPE],
[
  AC_CACHE_CHECK([whether pipes are FIFOs (and for their link count)],
    [gl_cv_pipes_are_fifos],
    [AC_RUN_IFELSE(
       [AC_LANG_SOURCE(
          [[#include <stdio.h>
            #include <sys/types.h>
            #include <sys/stat.h>
            #include <unistd.h>
            #ifndef S_ISFIFO
             #define S_ISFIFO(m) 0
            #endif
            #ifndef S_ISSOCK
             #define S_ISSOCK(m) 0
            #endif
            int
            main (int argc, char **argv)
            {
              int fd[2];
              struct stat st;
              if (pipe (fd) != 0)
                return 1;
              if (fstat (fd[0], &st) != 0)
                return 2;
              if (2 <= argc && argv[1][0] == '-')
                {
                  char const *yesno = (S_ISFIFO (st.st_mode) ? "yes" : "no");
                  if (st.st_nlink <= 1)
                    {
                      long int i = st.st_nlink;
                      if (i != st.st_nlink)
                        return 3;
                      printf ("%s (%ld)\n", yesno, i);
                    }
                  else
                    {
                      unsigned long int i = st.st_nlink;
                      if (i != st.st_nlink)
                        return 4;
                      printf ("%s (%lu)\n", yesno, i);
                    }
                }
              else
                {
                  if (! S_ISFIFO (st.st_mode) && ! S_ISSOCK (st.st_mode))
                    return 5;
                }
              return 0;
            }]])],
       [gl_cv_pipes_are_fifos=`./conftest$ac_exeext -`
        test -z "$gl_cv_pipes_are_fifos" && gl_cv_pipes_are_fifos=no],
       [gl_cv_pipes_are_fifos=unknown],
       [gl_cv_pipes_are_fifos=cross-compiling])])

  case $gl_cv_pipes_are_fifos in #(
  'yes ('*')')
    AC_DEFINE([HAVE_FIFO_PIPES], [1],
      [Define to 1 if pipes are FIFOs, 0 if sockets.  Leave undefined
       if not known.]);; #(
  'no ('*')')
    AC_DEFINE([HAVE_FIFO_PIPES], [0]);;
  esac

  case $gl_cv_pipes_are_fifos in #(
  *'('*')')
    AC_DEFINE_UNQUOTED([PIPE_LINK_COUNT_MAX],
      [`expr "$gl_cv_pipes_are_fifos" : '.*\((.*)\)'`],
      [Define to the maximum link count that a true pipe can have.]);;
  esac
])
