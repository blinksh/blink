#!/bin/sh
# Ensure that df exits non-Zero and writes an error message when
# --total is used but no file system has been processed.

# Copyright (C) 2012-2017 Free Software Foundation, Inc.

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
print_ver_ df
require_mount_list_

cat <<\EOF > exp || framework_failure_
df: no file systems processed
EOF

# Check we exit with non-Zero.
# Note we don't check when the file system can't be determined
# as -t filtering is not applied in that case.
if test "$(df --output=fstype . | tail -n1)" != '-'; then
  df -t _non_existent_fstype_ --total . 2>out && fail=1
  compare exp out || fail=1
fi

cat <<\EOF > exp || framework_failure_
df: _does_not_exist_: No such file or directory
EOF

# Ensure that df writes the error message also in the following case.
df --total _does_not_exist_ 2>out && fail=1
compare exp out || fail=1

Exit $fail
