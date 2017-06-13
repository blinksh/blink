# If possible, ignore libraries that are not depended on.

dnl Copyright (C) 2006, 2009-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

dnl Written by Paul Eggert.

# gl_IGNORE_UNUSED_LIBRARIES
# --------------------------
# Determines the option to be passed to the C/C++/Fortran compiler, so that it
# omits unused libraries.
# Example (on Solaris):
# $ cc foo.c -lnsl; ldd ./a.out
#         libnsl.so.1 =>   /lib/libnsl.so.1
#         libc.so.1 =>     /lib/libc.so.1
#         libmp.so.2 =>    /lib/libmp.so.2
#         libmd.so.1 =>    /lib/libmd.so.1
#         libscf.so.1 =>   /lib/libscf.so.1
#         libdoor.so.1 =>  /lib/libdoor.so.1
#         libuutil.so.1 =>         /lib/libuutil.so.1
#         libgen.so.1 =>   /lib/libgen.so.1
#         libm.so.2 =>     /lib/libm.so.2
# $ cc foo.c -lnsl -Wl,-z,ignore; ldd ./a.out
#         libc.so.1 =>     /lib/libc.so.1
#         libm.so.2 =>     /lib/libm.so.2
#
# Note that the option works only for the C compiler, not for the C++
# compiler:
# - Sun C likes '-Wl,-z,ignore'.
#   '-Qoption ld -z,ignore' is not accepted.
#   '-z ignore' is accepted but has no effect.
# - Sun C++ and Sun Fortran like '-Qoption ld -z,ignore'.
#   '-Wl,-z,ignore' is not accepted.
#   '-z ignore' is accepted but has no effect.
#
# Sets and substitutes a variable that depends on the current language:
# - IGNORE_UNUSED_LIBRARIES_CFLAGS    for C
# - IGNORE_UNUSED_LIBRARIES_CXXFLAGS  for C++
# - IGNORE_UNUSED_LIBRARIES_FFLAGS    for Fortran
#
# Note that the option works only for direct invocation of the compiler, not
# through libtool: When libtool is used to create a shared library, it will
# honor and translate '-Wl,-z,ignore' to '-Qoption ld -z -Qoption ld ignore'
# if needed, but it will drop a '-Qoption ld -z,ignore' on the command line.
#
AC_DEFUN([gl_IGNORE_UNUSED_LIBRARIES],
[
  AC_CACHE_CHECK([for []_AC_LANG[] compiler flag to ignore unused libraries],
    [gl_cv_prog_[]_AC_LANG_ABBREV[]_ignore_unused_libraries],
    [gl_cv_prog_[]_AC_LANG_ABBREV[]_ignore_unused_libraries=none
     gl_saved_ldflags=$LDFLAGS
     gl_saved_libs=$LIBS
     # Link with -lm to detect binutils 2.16 bug with --as-needed; see
     # <http://lists.gnu.org/archive/html/bug-gnulib/2006-06/msg00131.html>.
     LIBS="$LIBS -lm"
     # Use long option sequences like '-z ignore' to test for the feature,
     # to forestall problems with linkers that have -z, -i, -g, -n, etc. flags.
     # GCC + binutils likes '-Wl,--as-needed'.
     # GCC + Solaris ld likes '-Wl,-z,ignore'.
     # Sun C likes '-Wl,-z,ignore'. '-z ignore' is accepted but has no effect.
     # Don't try bare '--as-needed'; nothing likes it and the HP-UX 11.11
     # native cc issues annoying warnings and then ignores it,
     # which would cause us to incorrectly conclude that it worked.
     for gl_flags in _gl_IGNORE_UNUSED_LIBRARIES_OPTIONS
     do
       LDFLAGS="$gl_flags $LDFLAGS"
       AC_LINK_IFELSE([AC_LANG_PROGRAM()],
         [gl_cv_prog_[]_AC_LANG_ABBREV[]_ignore_unused_libraries=$gl_flags])
       LDFLAGS=$gl_saved_ldflags
       test "$gl_cv_prog_[]_AC_LANG_ABBREV[]_ignore_unused_libraries" != none &&
         break
     done
     LIBS=$gl_saved_libs
    ])
  IGNORE_UNUSED_LIBRARIES_[]_AC_LANG_PREFIX[]FLAGS=
  if test "$gl_cv_prog_[]_AC_LANG_ABBREV[]_ignore_unused_libraries" != none; then
    IGNORE_UNUSED_LIBRARIES_[]_AC_LANG_PREFIX[]FLAGS="$gl_cv_prog_[]_AC_LANG_ABBREV[]_ignore_unused_libraries"
  fi
  AC_SUBST([IGNORE_UNUSED_LIBRARIES_]_AC_LANG_PREFIX[FLAGS])
])

# _gl_IGNORE_UNUSED_LIBRARIES_OPTIONS
# -----------------------------------
# Expands to the language dependent options to be tried.
AC_DEFUN([_gl_IGNORE_UNUSED_LIBRARIES_OPTIONS],
[_AC_LANG_DISPATCH([$0], _AC_LANG, $@)])

# _gl_IGNORE_UNUSED_LIBRARIES_OPTIONS(C)
# --------------------------------------
m4_define([_gl_IGNORE_UNUSED_LIBRARIES_OPTIONS(C)],
[ '-Wl,--as-needed' \
  '-Wl,-z,ignore' \
  '-z ignore'
])

# _gl_IGNORE_UNUSED_LIBRARIES_OPTIONS(C++)
# ----------------------------------------
m4_define([_gl_IGNORE_UNUSED_LIBRARIES_OPTIONS(C++)],
[ '-Wl,--as-needed' \
  '-Qoption ld -z,ignore' \
  '-Wl,-z,ignore' \
  '-z ignore'
])

# _gl_IGNORE_UNUSED_LIBRARIES_OPTIONS(Fortran 77)
# -----------------------------------------------
m4_copy([_gl_IGNORE_UNUSED_LIBRARIES_OPTIONS(C++)],
        [_gl_IGNORE_UNUSED_LIBRARIES_OPTIONS(Fortran 77)])

# _gl_IGNORE_UNUSED_LIBRARIES_OPTIONS(Fortran)
# --------------------------------------------
m4_copy([_gl_IGNORE_UNUSED_LIBRARIES_OPTIONS(Fortran 77)],
        [_gl_IGNORE_UNUSED_LIBRARIES_OPTIONS(Fortran)])
