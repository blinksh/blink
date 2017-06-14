#!/bin/sh
# Test for this fix: 461231f022bdb3ee392622d31dc475034adceeb2.
# Ensure that seq prints exactly two numbers for a 2-number integral
# range at the limit of floating point precision.

# Copyright (C) 2008-2017 Free Software Foundation, Inc.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ seq
getlimits_

# Run this test only with glibc and sizeof (long double) > sizeof (double).
# Otherwise, there are known failures.
cat <<\EOF > long.c
#include <features.h>
#if defined __GNU_LIBRARY__ && __GLIBC__ >= 2
int foo[sizeof (long double) - sizeof (double) - 1];
#else
"run this test only with glibc"
#endif
EOF
$CC -c long.c \
  || skip_ \
     'this test runs only on systems with glibc and long double != double'

a=$INTMAX_MAX
b=$INTMAX_OFLOW

seq $a $b > out || fail=1
printf "$a\n$b\n" > exp || fail=1
compare exp out || fail=1

Exit $fail
