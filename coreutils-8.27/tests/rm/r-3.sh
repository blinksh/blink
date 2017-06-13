#!/bin/sh
# Create and remove a directory with more than 254 files.

# Copyright (C) 1997-2017 Free Software Foundation, Inc.

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


# An early version of my rewritten rm failed to remove all of
# the files on SunOS4 when there were 254 or more in a directory.

# And the rm from coreutils-5.0 exposes the same problem when there
# are 338 or more files in a directory on a Darwin-6.5 system

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ rm

mkdir t || framework_failure_
cd t || framework_failure_

# Create 500 files (20 * 25).
for i in 0 1 2 3 4 5 6 7 8 9 a b c d e f g h i j; do
  files=
  for j in a b c d e f g h i j k l m n o p q r s t u v w x y; do
    files="$files $i$j"
  done
  touch $files || framework_failure_
done

test -f 0a || framework_failure_
test -f by || framework_failure_
cd .. || framework_failure_

rm -rf t || fail=1
test -d t && fail=1

Exit $fail
