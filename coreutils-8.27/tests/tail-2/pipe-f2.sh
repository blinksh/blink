#!/bin/sh
# Ensure that "tail -f fifo" tails indefinitely.

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
print_ver_ tail

mkfifo_or_skip_ fifo

echo 1 > fifo &
echo 1 > exp || framework_failure_

# Terminate any background tail process
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

# Speedup the non inotify case
fastpoll='-s.1 --max-unchanged-stats=1'

timeout 10 tail $fastpoll -f fifo > out & pid=$!

check_tail_output() { sleep $1; test -s out; }

# Wait 12.7s for tail to write something.
retry_delay_ check_tail_output .1 7 || fail=1

compare exp out || fail=1

# Ensure tail is still running
kill -0 $pid || fail=1

cleanup_

Exit $fail
