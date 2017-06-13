#!/bin/sh
# Test cp --reflink=auto

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

cleanup_() { rm -rf "$other_partition_tmpdir"; }
. "$abs_srcdir/tests/other-fs-tmpdir"
a_other="$other_partition_tmpdir/a"
rm -f "$a_other" || framework_failure_

echo non_zero_size > "$a_other" || framework_failure_

# we shouldn't be able to reflink() files on separate partitions
returns_ 1 cp --reflink "$a_other" b || fail=1

# --reflink=auto should fall back to a normal copy
cp --reflink=auto "$a_other" b || fail=1
test -s b || fail=1

# --reflink=auto should allow --sparse for fallback copies.
# This command can be used to create minimal sized copies.
cp --reflink=auto --sparse=always "$a_other" b || fail=1
test -s b || fail=1

Exit $fail
