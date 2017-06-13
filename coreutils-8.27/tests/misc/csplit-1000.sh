#!/bin/sh
# cause a 1-byte heap buffer overrun

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
print_ver_ csplit

# Before coreutils-8.7, this would overrun the 6-byte filename_space buffer.
# It's hard to detect that without using valgrind, so here, we simply
# run the demonstrator.
seq 1000 | csplit - '/./' '{*}' || fail=1
test -f xx1000 || fail=1
test -f xx1001 && fail=1

Exit $fail
