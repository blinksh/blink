#!/bin/sh
# copy a sparse file to a pipe, to exercise some seldom-used parts of copy.c

# Copyright (C) 2011-2017 Free Software Foundation, Inc.

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

require_sparse_support_

# Terminate any background cp process
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

mkfifo_or_skip_ pipe
timeout 10 cat pipe > copy & pid=$!

truncate -s1M sparse || framework_failure_
cp sparse pipe || fail=1

# Ensure that the cat has completed before comparing.
wait $pid

cmp sparse copy || fail=1

Exit $fail
