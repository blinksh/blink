#!/bin/sh
# ensure that cp's --no-preserve=mode works correctly

# Copyright (C) 2002-2017 Free Software Foundation, Inc.

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
print_ver_ cp

rm -f a b c
umask 0022
touch a
touch b
chmod 600 b

#regular file test
cp --no-preserve=mode b c || fail=1
mode_a=$(ls -l a | gawk '{print $1}')
mode_c=$(ls -l c | gawk '{print $1}')
test "$mode_a" = "$mode_c" || fail=1

rm -rf d1 d2 d3
mkdir d1 d2
chmod 705 d2

#directory test
cp --no-preserve=mode -r d2 d3 || fail=1
mode_d1=$(ls -l d1 | gawk '{print $1}')
mode_d3=$(ls -l d3 | gawk '{print $1}')
test "$mode_d1" = "$mode_d3" || fail=1

rm -f a b c
touch a
chmod 600 a

#contradicting options test
cp --no-preserve=mode --preserve=all a b || fail=1
mode_a=$(ls -l a | gawk '{print $1}')
mode_b=$(ls -l b | gawk '{print $1}')
test "$mode_a" = "$mode_b" || fail=1

Exit $fail
