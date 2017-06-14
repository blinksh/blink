#!/bin/sh
# Make sure that cp -R DIR1 DIR2 does the right thing
# when DIR1 is written with a trailing slash.

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
print_ver_ cp

mkdir dir1 dir2 || framework_failure_
touch dir1/file || framework_failure_

cp -R dir1/ dir2 || fail=1

# This file should not exist, but it did with fileutils-4.0w.
test -r dir2/file && fail=1

# These two should.
test -r dir2/dir1/file || fail=1
test -r dir1/file || fail=1

Exit $fail
