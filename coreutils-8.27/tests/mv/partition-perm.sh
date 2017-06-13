#!/bin/sh
# Make sure permissions are preserved when moving from one partition to another.

# Copyright (C) 1999-2017 Free Software Foundation, Inc.

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

> file || framework_failure_
chmod a=rwx file || framework_failure_

umask 077
mv file "$other_partition_tmpdir" || framework_failure_

test -f file && fail=1
test -f "$other_partition_tmpdir/file" || fail=1

# This would have failed with the mv from fileutils-4.0i.
mode=$(ls -l "$other_partition_tmpdir/file" | cut -b-10)
test "$mode" = "-rwxrwxrwx" || fail=1

Exit $fail
