#!/bin/sh
# Ensure that df -P is not affected by BLOCK_SIZE settings

# Copyright (C) 2007-2017 Free Software Foundation, Inc.

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


              df -P . > t1 || fail=1
BLOCK_SIZE=1M df -P . > t2 || fail=1

# Since disk utilization may be changing, compare only df's header line.
# That records the block size.  E.g., for "1M", it would be:
# Filesystem         1048576-blocks      Used Available Capacity Mounted on
# while for 1K, it would be
# Filesystem         1024-blocks      Used Available Capacity Mounted on

head -n1 t1 > exp || fail=1
head -n1 t2 > out || fail=1

compare exp out || fail=1

Exit $fail
