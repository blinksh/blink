#!/bin/sh
# Ensure sort -g sorts floating point limits correctly

# Copyright (C) 2010-2017 Free Software Foundation, Inc.

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
print_ver_ sort

# Return 0 if LDBL_MIN is smaller than DBL_MIN, else 1.
# Dissect numbers like these, comparing first exponent, then
# whole part of mantissa, then fraction, until finding enough
# of a difference to determine the relative order of the numbers.
# These are "reversed":
#   $ ./getlimits |grep DBL_MIN
#   DBL_MIN=2.225074e-308
#   LDBL_MIN=2.004168e-292
#
# These are in the expected order:
#   $ ./getlimits|grep DBL_MIN
#   DBL_MIN=2.225074e-308
#   LDBL_MIN=3.362103e-4932

dbl_minima_order()
{
  LC_ALL=C getlimits_
  set -- $(echo $LDBL_MIN | tr .e- '   ')
  local ldbl_whole=$1 ldbl_frac=$2 ldbl_exp=$3

  set -- $(echo $DBL_MIN |tr .e- '   ')
  local dbl_whole=$1 dbl_frac=$2 dbl_exp=$3

  test "$dbl_exp"    -lt "$ldbl_exp"   && return 0
  test "$ldbl_exp"   -lt "$dbl_exp"    && return 1
  test "$ldbl_whole" -lt "$dbl_whole"  && return 0
  test "$dbl_whole"  -lt "$ldbl_whole" && return 1
  test "$ldbl_frac"  -le "$dbl_frac"   && return 0
  return 1
}

# On some systems, DBL_MIN < LDBL_MIN.  Detect that.
dbl_minima_order; reversed=$?

for LOC in C $LOCALE_FR; do

  LC_ALL=$LOC getlimits_

  # See if sort should be using long doubles
  grep '^#define HAVE_C99_STRTOLD 1' $CONFIG_HEADER > /dev/null ||
    { LDBL_MAX="$DBL_MAX"; LDBL_MIN="$DBL_MIN"; }

  # If DBL_MIN happens to be smaller than LDBL_MIN, swap them,
  # so that out expected output is sorted.
  if test $reversed = 1; then
    t=$LDBL_MIN
    LDBL_MIN=$DBL_MIN
    DBL_MIN=$t
  fi

  printf -- "\
-$LDBL_MAX
-$DBL_MAX
-$FLT_MAX
-$FLT_MIN
-$DBL_MIN
-$LDBL_MIN
0
$LDBL_MIN
$DBL_MIN
$FLT_MIN
$FLT_MAX
$DBL_MAX
$LDBL_MAX
" |
  grep '^[0-9.,e+-]*$' > exp # restrict to numeric just in case

  tac exp | LC_ALL=$LOC sort -sg > out || fail=1

  compare exp out || fail=1
done

Exit $fail
