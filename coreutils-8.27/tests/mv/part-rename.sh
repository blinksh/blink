#!/bin/sh
# Test various cases for moving directories across file systems

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
print_ver_ mv
cleanup_() { rm -rf "$other_partition_tmpdir"; }
. "$abs_srcdir/tests/other-fs-tmpdir"


# Moving a directory specified with a trailing slash from one partition to
# another, and giving it a different name at the destination would cause mv
# to get a failed assertion.
mkdir foo || framework_failure_
mv foo/ "$other_partition_tmpdir/bar" || fail=1


# Moving a non directory from source shouldn't replace empty dir in dest
touch bar || framework_failure_
returns_ 1 mv bar "$other_partition_tmpdir/" || fail=1


# Moving a directory from source shouldn't replace non directory in dest
mkdir bar2
touch "$other_partition_tmpdir/bar2"
returns_ 1 mv bar2 "$other_partition_tmpdir/" || fail=1


# As per POSIX moving directory from source should replace empty dir in dest
mkdir bar3
touch bar3/file
mkdir "$other_partition_tmpdir/bar3"
mv bar3 "$other_partition_tmpdir/" || fail=1
test -e "$other_partition_tmpdir/bar3/file" || fail=1


# As per POSIX moving directory from source shouldn't update dir in dest
mkdir bar3
touch bar3/file2
returns_ 1 mv bar3 "$other_partition_tmpdir/" || fail=1
test -e "$other_partition_tmpdir/bar3/file2" && fail=1

Exit $fail
