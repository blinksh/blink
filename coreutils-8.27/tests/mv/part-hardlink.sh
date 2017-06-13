#!/bin/sh
# Ensure that hard links are preserved when moving between partitions
# and when the links are in separate command line arguments.
# For additional constraints, see the comment in copy.c.
# Before coreutils-5.2.1, this test would fail.

# Copyright (C) 2004-2017 Free Software Foundation, Inc.

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

touch f || framework_failure_
ln f g || framework_failure_
mkdir a b || framework_failure_
touch a/1 || framework_failure_
ln a/1 b/1 || framework_failure_


mv f g "$other_partition_tmpdir" || fail=1
mv a b "$other_partition_tmpdir" || fail=1

cd "$other_partition_tmpdir"
set $(ls -Ci f g)
test $1 = $3 || fail=1
set $(ls -Ci a/1 b/1)
test $1 = $3 || fail=1

Exit $fail
