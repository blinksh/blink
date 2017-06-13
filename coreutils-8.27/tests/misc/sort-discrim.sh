#!/bin/sh
# Test discriminator-based sorting.

# Copyright (C) 2012-2017 Free Software Foundation, Inc.

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

# Set limit variables.
getlimits_

# These tests are designed for a 'sort' implementation that uses a
# discriminator, i.e., a brief summary of a key that may have lost info,
# but whose ordering is consistent with that of the original key.
# The tests are useful even if 'sort' does not use this representation.

# Test lexicographic sorting.

# A long-enough string so that it overruns a small discriminator buffer size.
long_prefix='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
seq -f "$long_prefix%5.0f" 10000 > exp || fail=1
sort -R exp | LC_ALL=C sort > out || fail=1
compare exp out || fail=1


# Test numeric sorting.

# These tests are designed for an internal representation that ordinarily
# looks at the number plus two decimal digits, but if -h is
# used it looks at one decimal place plus a 4-bit SI prefix value.
# In both cases, there's an extra factor of 2 for the sign.
# Note INTMAX_MAX is used below as that's that largest number
# expr can handle on all systems (without GMP).
max_int100=$(expr $INTMAX_MAX / 100) &&
max_frac100=$(printf '%.2d' $(expr $INTMAX_MAX % 100)) &&
max_int160=$(expr $INTMAX_MAX / 160) &&
max_frac160=$(expr $INTMAX_MAX / 16 % 10) &&
{ printf -- "\
    -$UINTMAX_OFLOW
    -$UINTMAX_MAX
    -${max_int100}0.1
    -${max_int100}0
    -${max_int100}0.0
    -${max_int160}0.1
    -${max_int160}0
    -${max_int160}0.0
    -$max_int100.${max_frac100}1
    -$max_int100.$max_frac100
    -$max_int160.${max_frac160}1
    -$max_int160.$max_frac160
" &&
  seq -- -10 .001 10 &&
  printf "\
    $max_int160
    $max_int160.$max_frac160
    $max_int160.${max_frac160}1
    $max_int100
    $max_int100.$max_frac100
    $max_int100.${max_frac100}1
    ${max_int160}0
    ${max_int160}0.0
    ${max_int160}0.1
    ${max_int100}0
    ${max_int100}0.0
    ${max_int100}0.1
    $UINTMAX_MAX
    $UINTMAX_OFLOW
"
} > exp || fail=1

for opts in -n -h; do
  sort -R exp | LC_ALL=C sort $opts > out || fail=1
  compare exp out || fail=1
done

Exit $fail
