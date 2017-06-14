# Determine whether we can write any file.

# Copyright (C) 2007, 2009-2017 Free Software Foundation, Inc.
#
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

# Written by Paul Eggert.

AC_DEFUN([gl_WRITE_ANY_FILE],
[
  AC_CHECK_HEADERS_ONCE([priv.h])
])
