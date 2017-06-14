#!/bin/sh
# Ensure that mv prints the right diagnostic for a dir->dir move
# where the destination directory is not empty.

# Copyright (C) 2006-2017 Free Software Foundation, Inc.

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
print_ver_ mv

mkdir -p a/t b/t || framework_failure_
touch a/t/f || framework_failure_


# Expect this to fail with the expected diagnostic.
# For an interim (pre-6.0) release, it would give an erroneous
# diagnostic about moving one directory to a subdirectory of itself.
mv b/t a 2> out && fail=1

# Accept any of these: EEXIST, ENOTEMPTY, EBUSY.
sed             's/: File exists/: Directory not empty/'<out>o1;mv o1 out
sed 's/: Device or resource busy/: Directory not empty/'<out>o1;mv o1 out

cat <<\EOF > exp || fail=1
mv: cannot move 'b/t' to 'a/t': Directory not empty
EOF

compare exp out || fail=1

Exit $fail
