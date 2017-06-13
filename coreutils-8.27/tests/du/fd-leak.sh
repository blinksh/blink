#!/bin/sh
# check for file descriptor leak

# Copyright (C) 2003-2017 Free Software Foundation, Inc.

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
print_ver_ du

# Call this an expensive test.  It's not that expensive, but command line
# limitations might induce failure on some losing systems.
expensive_

# Create 1296 (36^2) files.
# Their names and separating spaces take up 3887 bytes.
x='a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9'
f=
for i in $x; do
  for j in $x; do
    f="$f $i$j"
  done
done

# This may fail due to command line limitations.
touch $f || framework_failure_


# With coreutils-5.0, this would fail due to a file descriptor leak.
du $f > out || fail=1

Exit $fail
