#!/bin/sh
# Validate truncate integer overflow

# Copyright (C) 2008-2017 Free Software Foundation, Inc.

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
print_ver_ truncate
getlimits_


# -= overflow
truncate -s-1 create-zero-len-file || fail=1

echo > non-empty-file

# signed overflow
returns_ 1 truncate -s$OFF_T_OFLOW file || fail=1

# += signed overflow
returns_ 1 truncate -s+$OFF_T_MAX non-empty-file || fail=1

# *= signed overflow
IO_BLOCK_OFLOW=$(expr $OFF_T_MAX / $(stat -f -c%s .) + 1)
returns_ 1 truncate --io-blocks --size=$IO_BLOCK_OFLOW file || fail=1

Exit $fail
