#!/bin/sh
# inotify-based tail would output redundant headers for
# overlapping inotify events while it was suspended

# Copyright (C) 2017 Free Software Foundation, Inc.

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
print_ver_ tail sleep

# Function to count number of lines from tail
# while ignoring transient errors due to resource limits
countlines_ ()
{
  grep -Ev 'inotify (resources exhausted|cannot be used)' out | wc -l
}

# Function to check the expected line count in 'out'.
# Called via retry_delay_().  Sleep some time - see retry_delay_() - if the
# line count is still smaller than expected.
wait4lines_ ()
{
  local delay=$1
  local elc=$2   # Expected line count.
  [ "$(countlines_)" -ge "$elc" ] || { sleep $delay; return 1; }
}

# Speedup the non inotify case
fastpoll='---dis -s.1 --max-unchanged-stats=1'

# Terminate any background tail process
cleanup_() {
  kill $pid 2>/dev/null && wait $pid;
  kill $sleep 2>/dev/null && wait $sleep
}

echo start > file1 || framework_failure_
echo start > file2 || framework_failure_

# Use this as a way to gracefully terminate tail
env sleep 20 & sleep=$!

tail $fastpoll --pid=$sleep -f file1 file2 > out & pid=$!

kill -0 $pid || fail=1

# Wait for 5 initial lines
retry_delay_ wait4lines_ .1 6 5 || fail=1

# Suspend tail so single read() caters for multiple inotify events
kill -STOP $pid || fail=1

# Interleave writes to files to generate overlapping inotify events
echo line >> file1 || framework_failure_
echo line >> file2 || framework_failure_
echo line >> file1 || framework_failure_
echo line >> file2 || framework_failure_

# Resume tail processing
kill -CONT $pid || fail=1

# Wait for 8 more lines
retry_delay_ wait4lines_ .1 6 13 || fail=1

kill $sleep && wait || framework_failure_

test "$(countlines_)" = 13 || fail=1

Exit $fail
