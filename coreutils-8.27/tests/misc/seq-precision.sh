#!/bin/sh
# Test for output with appropriate precision

# Copyright (C) 2015-2017 Free Software Foundation, Inc.

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

# Integer only.  Before v8.24 these would switch output format

seq 999999 inf | head -n2 > out || fail=1
printf "%s\n" 999999 1000000 > exp || framework_failure_
compare exp out || fail=1

# Exercise buffer handling in non floating point output
for i in $(seq 100); do
  n1="$(printf '%*s' $i '' | tr ' ' 9)"
  n2="1$(echo $n1 | tr 9 0)"

  seq $n1 $n2 > out || fail=1
  printf "%s\n" "$n1" "$n2" > exp || framework_failure_
  compare exp out || fail=1
done

seq 0xF423F 0xF4240 > out || fail=1
printf "%s\n" 999999 1000000 > exp || framework_failure_
compare exp out || fail=1

# Ensure consistent precision for inf
seq 1 .1 inf | head -n2 > out || fail=1
printf "%s\n" 1.0 1.1 > exp || framework_failure_
compare exp out || fail=1

# Ensure standard output methods with inf start
seq inf inf | head -n2 | uniq > out || fail=1
test "$(wc -l < out)" = 1 || fail=1

# Ensure auto precision for hex float
seq 1 0x1p-1 2 > out || fail=1
printf "%s\n" 1 1.5 2 > exp || framework_failure_
compare exp out || fail=1

# Ensure consistent precision for hex
seq 1 .1 0x2 | head -n2 > out || fail=1
printf "%s\n" 1.0 1.1 > exp || framework_failure_
compare exp out || fail=1

# Ensure consistent handling of precision/width for exponents

seq 1.1e1 12 > out || fail=1
printf "%s\n" 11 12 > exp || framework_failure_
compare exp out || fail=1

seq 11 1.2e1 > out || fail=1
printf "%s\n" 11 12 > exp || framework_failure_
compare exp out || fail=1

seq -w 1.1e4 | head -n1 > out || fail=1
printf "%s\n" 00001 > exp || framework_failure_
compare exp out || fail=1

seq -w 1.10000e5 1.10000e5 > out || fail=1
printf "%s\n" 110000 > exp || framework_failure_
compare exp out || fail=1

Exit $fail
