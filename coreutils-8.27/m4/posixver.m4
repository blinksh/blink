# posixver.m4 serial 12
dnl Copyright (C) 2002-2006, 2009-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_POSIXVER],
[
  AC_REQUIRE([gl_DEFAULT_POSIX2_VERSION])
])

# Set the default level of POSIX conformance at configure-time.
# Build with './configure DEFAULT_POSIX2_VERSION=199209 ...' to
# support the older version, thus preserving portability with
# scripts that use sort +1, tail +32, etc.
# Note however, that this breaks tools that might run commands
# like 'sort +some-file' that conform with the newer standard.
AC_DEFUN([gl_DEFAULT_POSIX2_VERSION],
[
  AC_MSG_CHECKING([for desired default level of POSIX conformance])
  gl_default_posix2_version=none-specified
  if test -n "$ac_cv_env_DEFAULT_POSIX2_VERSION_set"; then
    gl_default_posix2_version=$ac_cv_env_DEFAULT_POSIX2_VERSION_value
    AC_DEFINE_UNQUOTED([DEFAULT_POSIX2_VERSION],
      $gl_default_posix2_version,
      [Define the default level of POSIX conformance. The value is of
       the form YYYYMM, specifying the year and month the standard was
       adopted. If not defined here, it defaults to the value of
       _POSIX2_VERSION in <unistd.h>. Define to 199209 to default to
       POSIX 1003.2-1992, which makes standard programs like 'head',
       'tail', and 'sort' accept obsolete options like '+10' and
       '-10'. Define to 200112 to default to POSIX 1003.1-2001, which
       makes these standard programs treat leading-'+' operands as
       file names and require modern usages like '-n 10' instead of
       '-10'. Whether defined here or not, the default can be
       overridden at run time via the _POSIX2_VERSION environment
       variable.])
  fi
  AC_MSG_RESULT([$gl_default_posix2_version])
  AC_ARG_VAR(
    [DEFAULT_POSIX2_VERSION],
    [POSIX version to default to; see 'config.hin'.])
])
