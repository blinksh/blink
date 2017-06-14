#!/bin/sh
# Verify that 'od -N N' reads no more than N bytes of input.

# Copyright (C) 2001-2017 Free Software Foundation, Inc.

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
print_ver_ od

echo abcdefg > in || framework_failure_


(od -An -N3 -c; od -An -N3 -c) < in > out
cat <<EOF > exp || fail=1
   a   b   c
   d   e   f
EOF
compare exp out || fail=1

Exit $fail
