#!/bin/sh
# Ensure that ls --file-type does not call stat unnecessarily.
# Also check for the dtype-related (and fs-type dependent) bug
# in coreutils-6.0 that made ls -CF columns misaligned.

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

# The trick is to create an un-stat'able symlink and to see if ls
# can report its type nonetheless, using dirent.d_type.

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ ls

# Skip this test unless "." is on a file system with useful d_type info.
# FIXME: This uses "ls -p" to decide whether to test "ls" with other options,
# but if ls's d_type code is buggy then "ls -p" might be buggy too.
mkdir -p c/d || framework_failure_
chmod a-x c || framework_failure_
if test "X$(ls -p c 2>&1)" != Xd/; then
  skip_ "'.' is not on a suitable file system for this test"
fi

mkdir d || framework_failure_
ln -s / d/s || framework_failure_
chmod 600 d || framework_failure_

mkdir -p e/a2345 e/b || framework_failure_
chmod 600 e || framework_failure_


ls --file-type d > out || fail=1
cat <<\EOF > exp || fail=1
s@
EOF

compare exp out || fail=1

rm -f out exp
# Check for the ls -CF misaligned-columns bug:
ls -CF e > out || fail=1

# coreutils-6.0 would print two spaces after the first slash,
# rather than the appropriate TAB.
printf 'a2345/\tb/\n' > exp || fail=1

compare exp out || fail=1

Exit $fail
