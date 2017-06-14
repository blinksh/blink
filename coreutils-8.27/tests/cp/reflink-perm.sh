#!/bin/sh
# Test cp --reflink copies permissions

# Copyright (C) 2009-2017 Free Software Foundation, Inc.

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


> time_check
> file
ts='2009-08-28 19:00'
touch -d "$ts" file || framework_failure_
test time_check -nt file || skip_ "The system clock is wrong"

chmod a=rwx file || framework_failure_
umask 077
cp --reflink=auto --preserve file copy || fail=1

mode=$(stat --printf "%A" copy)
test "$mode" = "-rwxrwxrwx" || fail=1

test copy -nt file && fail=1

# Ensure that --attributes-only overrides --reflink completely
echo > file2 # file with data
cp --reflink=auto --preserve --attributes-only file2 empty_copy || fail=1
compare /dev/null empty_copy || fail=1
cp --reflink=always --preserve --attributes-only file2 empty_copy || fail=1
compare /dev/null empty_copy || fail=1

Exit $fail
