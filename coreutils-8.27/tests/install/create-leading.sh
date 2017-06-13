#!/bin/sh
# Test -D option.

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

# Note that the tests below use 'ginstall', not install, because
# that's the name of the binary in ../../src.

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ ginstall


file=file
echo foo > $file || framework_failure_

# Before 4.0q, this would mistakenly create $file, not 'dest'
# in no-dir1/no-dir2/.
ginstall -D $file no-dir1/no-dir2/dest || fail=1
test -d no-dir1/no-dir2 || fail=1
test -r no-dir1/no-dir2/dest || fail=1

# Between 6.1 and 8.24, this would not copy $file
# due to incorrectly modified working directory
mkdir dir1 || framework_failure_
touch dir1/file1 || framework_failure_
ginstall -D "$PWD/dir1/file1" $file -t "$PWD/no-dir2/" || fail=1
test -r no-dir2/$file && test -r no-dir2/file1 || fail=1

Exit $fail
