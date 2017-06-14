#!/bin/sh
# Ensure that wc prints counts atomically
# so that concurrent processes don't intersperse their output

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
print_ver_ wc

xargs -P2 </dev/null >/dev/null 2>&1 \
  || skip_ 'xargs -P is required'

(mkdir tmp && cd tmp && seq 2000 | xargs touch)

# This will output at least 16KiB per process
# and start 3 processes, with 2 running concurrently,
# which triggers often on Fedora 11 at least.
(find tmp tmp tmp -type f | xargs -n2000 -P2 wc 2>err) |
sed -n '/0 0 0 /!p' |
grep . > /dev/null && fail=1
compare /dev/null err || fail=1

Exit $fail
