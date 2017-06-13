#!/bin/sh
# ensure that dd's oflag=direct works

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
print_ver_ dd

truncate -s 8192 in || framework_failure_
dd if=in oflag=direct of=out 2> /dev/null \
  || skip_ 'this file system lacks support for O_DIRECT'

truncate -s 511 short || framework_failure_
truncate -s 8191 m1 || framework_failure_
truncate -s 8193 p1 || framework_failure_

for i in short m1 p1; do
  rm -f out
  dd if=$i oflag=direct of=out || fail=1
done

Exit $fail
