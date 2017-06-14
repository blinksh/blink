# serial 4
# Check for flexible array member support.

# Copyright (C) 2006, 2009-2017 Free Software Foundation, Inc.
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

# Written by Paul Eggert.

AC_DEFUN([AC_C_FLEXIBLE_ARRAY_MEMBER],
[
  AC_CACHE_CHECK([for flexible array member],
    ac_cv_c_flexmember,
    [AC_COMPILE_IFELSE(
       [AC_LANG_PROGRAM(
          [[#include <stdlib.h>
            #include <stdio.h>
            #include <stddef.h>
            struct s { int n; double d[]; };]],
          [[int m = getchar ();
            size_t nbytes = offsetof (struct s, d) + m * sizeof (double);
            nbytes += sizeof (struct s) - 1;
            nbytes -= nbytes % sizeof (struct s);
            struct s *p = malloc (nbytes);
            p->d[0] = 0.0;
            return p->d != (double *) NULL;]])],
       [ac_cv_c_flexmember=yes],
       [ac_cv_c_flexmember=no])])
  if test $ac_cv_c_flexmember = yes; then
    AC_DEFINE([FLEXIBLE_ARRAY_MEMBER], [],
      [Define to nothing if C supports flexible array members, and to
       1 if it does not.  That way, with a declaration like 'struct s
       { int n; double d@<:@FLEXIBLE_ARRAY_MEMBER@:>@; };', the struct hack
       can be used with pre-C99 compilers.
       When computing the size of such an object, don't use 'sizeof (struct s)'
       as it overestimates the size.  Use 'offsetof (struct s, d)' instead.
       Don't use 'offsetof (struct s, d@<:@0@:>@)', as this doesn't work with
       MSVC and with C++ compilers.])
  else
    AC_DEFINE([FLEXIBLE_ARRAY_MEMBER], [1])
  fi
])
