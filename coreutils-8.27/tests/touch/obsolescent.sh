#!/bin/sh
# Test touch with obsolescent 8- or 10-digit timestamps.

# Copyright (C) 2000-2017 Free Software Foundation, Inc.

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
print_ver_ touch

_POSIX2_VERSION=199209; export _POSIX2_VERSION
POSIXLY_CORRECT=1; export POSIXLY_CORRECT


yearstart=01010000

for ones in 11111111 1111111111; do
  for args in $ones "-- $ones" "$yearstart $ones" "-- $yearstart $ones"; do
    touch $args || fail=1
    test -f $ones || fail=1
    test -f $yearstart && fail=1
    rm -f $ones || fail=1
  done
done

y2000=0101000000
rm -f $y2000 file || fail=1
touch $y2000 file && test -f $y2000 && test -f file || fail=1

Exit $fail
