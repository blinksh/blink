#!/bin/sh
# Exercise shred --size

# Copyright (C) 2014-2017 Free Software Foundation, Inc.

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
print_ver_ shred

# Negative size
echo "shred: invalid file size: '-2'" > exp || framework_failure_
echo 1234 > f || framework_failure_
shred -s-2 f 2>err && fail=1
compare exp err || fail=1

# Octal/Hex
shred -s010 f || fail=1
test $(stat --printf=%s f) = 8 || fail=1
shred -s0x10 f || fail=1
test $(stat --printf=%s f) = 16 || fail=1

Exit $fail
