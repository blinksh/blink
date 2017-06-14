#!/bin/sh
# Test functionality of --exact

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
print_ver_ shred


# make sure that neither --exact nor --zero gobbles a command line argument
for opt in --exact --zero; do
  echo a > a || fail=1
  echo bb > b || fail=1
  echo ccc > c || fail=1

  shred --remove $opt a b || fail=1
  test -f a && fail=1
  test -f b && fail=1

  shred --remove $opt c || fail=1
  test -f c && fail=1
done


# make sure direct I/O is handled appropriately at end of file
# Create a 1MiB file as we'll probably not be using blocks larger than that
# (i.e., we want to test failed writes not at the start).
truncate -s1MiB file.slop || framework_failure_
truncate -s+1 file.slop || framework_failure_
shred --exact -n2 file.slop || fail=1

# make sure direct I/O is handled appropriately at start of file
truncate -s1 file.slop || framework_failure_
shred --exact -n2 file.slop || fail=1

Exit $fail
