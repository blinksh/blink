#!/bin/sh
# Make sure that the copying code used in an inter-partition
# move unlinks a destination symlink before opening it.

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

rem_file="$other_partition_tmpdir/file"
rem_symlink="$other_partition_tmpdir/symlink"
file=to-sym

echo local > $file || framework_failure_
echo remote > $rem_file || framework_failure_
ln -s $rem_file $rem_symlink || framework_failure_

# This mv command should succeed, unlinking the symlink
# before copying.
mv $file $rem_symlink || fail=1

# Make sure $file is gone.
test -f $file && fail=1

# Make sure $rem_file is unmodified.
test $(cat $rem_file) = remote || fail=1

Exit $fail
