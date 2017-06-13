# Check for stdalign.h that conforms to C11.

dnl Copyright 2011-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

# Prepare for substituting <stdalign.h> if it is not supported.

AC_DEFUN([gl_STDALIGN_H],
[
  AC_CACHE_CHECK([for working stdalign.h],
    [gl_cv_header_working_stdalign_h],
    [AC_COMPILE_IFELSE(
       [AC_LANG_PROGRAM(
          [[#include <stdalign.h>
            #include <stddef.h>

            /* Test that alignof yields a result consistent with offsetof.
               This catches GCC bug 52023
               <http://gcc.gnu.org/bugzilla/show_bug.cgi?id=52023>.  */
            #ifdef __cplusplus
               template <class t> struct alignof_helper { char a; t b; };
            # define ao(type) offsetof (alignof_helper<type>, b)
            #else
            # define ao(type) offsetof (struct { char a; type b; }, b)
            #endif
            char test_double[ao (double) % _Alignof (double) == 0 ? 1 : -1];
            char test_long[ao (long int) % _Alignof (long int) == 0 ? 1 : -1];
            char test_alignof[alignof (double) == _Alignof (double) ? 1 : -1];

            /* Test _Alignas only on platforms where gnulib can help.  */
            #if \
                ((defined __cplusplus && 201103 <= __cplusplus) \
                 || (defined __APPLE__ && defined __MACH__ \
                     ? 4 < __GNUC__ + (1 <= __GNUC_MINOR__) \
                     : __GNUC__) \
                 || __HP_cc || __HP_aCC || __IBMC__ || __IBMCPP__ \
                 || __ICC || 0x5110 <= __SUNPRO_C \
                 || 1300 <= _MSC_VER)
              struct alignas_test { char c; char alignas (8) alignas_8; };
              char test_alignas[offsetof (struct alignas_test, alignas_8) == 8
                                ? 1 : -1];
            #endif
          ]])],
       [gl_cv_header_working_stdalign_h=yes],
       [gl_cv_header_working_stdalign_h=no])])

  if test $gl_cv_header_working_stdalign_h = yes; then
    STDALIGN_H=''
  else
    STDALIGN_H='stdalign.h'
  fi

  AC_SUBST([STDALIGN_H])
  AM_CONDITIONAL([GL_GENERATE_STDALIGN_H], [test -n "$STDALIGN_H"])
])
