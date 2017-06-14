#!/bin/sh
# move a directory containing hard-linked files and
# make sure the links are preserved

# Copyright (C) 1998-2017 Free Software Foundation, Inc.

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

dir=hlink

mkdir $dir || framework_failure_
> $dir/a || framework_failure_
ln $dir/a $dir/b || framework_failure_

mv $dir "$other_partition_tmpdir" || fail=1

# Display inode numbers, one per line.
ls -1i "$other_partition_tmpdir/$dir" > out || fail=1

# Make sure the inode numbers are the same.
a=$(sed -n 's/ a$//p' out)
b=$(sed -n 's/ b$//p' out)
test "$a" = "$b" || fail=1

Exit $fail
