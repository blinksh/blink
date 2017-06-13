# Determine whether recent-enough GNU Make is being used.

# Copyright (C) 2007, 2009-2017 Free Software Foundation, Inc.

# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

# Written by Paul Eggert.

# Set GNU_MAKE if we are using a recent-enough version of GNU make.

# Use --version AND trailing junk, because SGI Make doesn't fail on --version.

AC_DEFUN([gl_GNU_MAKE],
[
  AM_CONDITIONAL([GNU_MAKE],
    [${MAKE-make} --version /cannot/make/this >/dev/null 2>&1])
])
