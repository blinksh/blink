# md5.m4 serial 14
dnl Copyright (C) 2002-2006, 2008-2017 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_MD5],
[
  dnl Prerequisites of lib/md5.c.
  AC_REQUIRE([gl_BIGENDIAN])

  dnl Determine HAVE_OPENSSL_MD5 and LIB_CRYPTO
  gl_CRYPTO_CHECK([MD5])
])
