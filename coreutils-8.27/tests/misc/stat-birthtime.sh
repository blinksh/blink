#!/bin/sh
# ensure that stat attempts birthtime access

# Copyright (C) 2010-2017 Free Software Foundation, Inc.

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
print_ver_ stat

# Whether birthtime is supported or not, it better not change even when
# [acm]time are modified.  :)
touch a || fail=1
btime=$(stat --format %W a) || fail=1
atime=$(stat --format %X a) || fail=1
mtime=$(stat --format %Y a) || fail=1
ctime=$(stat --format %Z a) || fail=1

# Wait up to 2.17s for timestamps to change.
# ----------------------------------------
# iterations   file system resolution  e.g.
# ----------------------------------------
# 1            nano or micro second    ext4
# 4            1 second                ext3
# 5            2 second                FAT
# ----------------------------------------
check_timestamps_updated()
{
  local delay="$1"
  sleep $delay
  touch a || fail=1

  test "x$btime" = x$(stat --format %W a) &&
  test "x$atime" != x$(stat --format %X a) &&
  test "x$mtime" != x$(stat --format %Y a) &&
  test "x$ctime" != x$(stat --format %Z a)
}
retry_delay_ check_timestamps_updated .07 5 || fail=1

Exit $fail
