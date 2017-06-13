# strncat.m4 serial 2
dnl Copyright (C) 2002-2004, 2009-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN_ONCE([gl_FUNC_STRNCAT],
[
  AC_REQUIRE([gl_HEADER_STRING_H_DEFAULTS])
  AC_REQUIRE([AC_PROG_CC])
  AC_REQUIRE([AC_CANONICAL_HOST]) dnl for cross-compiles

  dnl Check for prerequisites for memory fence checks.
  gl_FUNC_MMAP_ANON
  AC_CHECK_HEADERS_ONCE([sys/mman.h])
  AC_CHECK_FUNCS_ONCE([mprotect])

  dnl Detect bug in Solaris 8..10 on SPARC:
  dnl strncat should not dereference more than n bytes, but always dereferences
  dnl n+1 bytes if the first n bytes don't contain a NUL byte.
  dnl Assume that strncat works on platforms that lack mprotect.
  AC_CACHE_CHECK([whether strncat works], [gl_cv_func_strncat_works],
    [AC_RUN_IFELSE([AC_LANG_PROGRAM([[
#include <string.h>
#if HAVE_SYS_MMAN_H
# include <fcntl.h>
# include <unistd.h>
# include <sys/types.h>
# include <sys/mman.h>
# ifndef MAP_FILE
#  define MAP_FILE 0
# endif
#endif
]], [[
  char *fence = NULL;
#if HAVE_SYS_MMAN_H && HAVE_MPROTECT
# if HAVE_MAP_ANONYMOUS
  const int flags = MAP_ANONYMOUS | MAP_PRIVATE;
  const int fd = -1;
# else /* !HAVE_MAP_ANONYMOUS */
  const int flags = MAP_FILE | MAP_PRIVATE;
  int fd = open ("/dev/zero", O_RDONLY, 0666);
  if (fd >= 0)
# endif
    {
      int pagesize = getpagesize ();
      char *two_pages =
        (char *) mmap (NULL, 2 * pagesize, PROT_READ | PROT_WRITE,
                       flags, fd, 0);
      if (two_pages != (char *)(-1)
          && mprotect (two_pages + pagesize, pagesize, PROT_NONE) == 0)
        fence = two_pages + pagesize;
    }
#endif
  if (fence)
    {
      char dest[8];

      dest[0] = '*';
      dest[1] = 'a';
      dest[2] = '\0';
      dest[3] = 'w';
      dest[4] = 'x';
      dest[5] = 'y';
      dest[6] = 'z';

      *(fence - 3) = '7';
      *(fence - 2) = '2';
      *(fence - 1) = '9';

      if (strncat (dest + 1, fence - 3, 3) != dest + 1)
        return 1;
      if (dest[0] != '*')
        return 2;
      if (dest[1] != 'a'
          || dest[2] != '7' || dest[3] != '2' || dest[4] != '9'
          || dest[5] != '\0')
        return 3;
      if (dest[6] != 'z')
        return 4;
    }
  return 0;
]])], [gl_cv_func_strncat_works=yes], [gl_cv_func_strncat_works=no],
       [
        case "$host_os" in
                    # Guess no on Solaris.
          solaris*) gl_cv_func_strncat_works="guessing no";;
                    # Guess yes otherwise.
          *)        gl_cv_func_strncat_works="guessing yes";;
        esac
       ])
    ])
  case "$gl_cv_func_strncat_works" in
    *yes) ;;
    *) REPLACE_STRNCAT=1 ;;
  esac
])

# Prerequisites of lib/strncat.c.
AC_DEFUN([gl_PREREQ_STRNCAT], [
  :
])
