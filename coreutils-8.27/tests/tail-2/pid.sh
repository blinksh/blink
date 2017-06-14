#!/bin/sh
# Test the --pid option of tail.

# Copyright (C) 2003-2017 Free Software Foundation, Inc.

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
getlimits_

touch empty here || framework_failure_

# Terminate any background tail process
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

for mode in '' '---disable-inotify'; do
  # Use tail itself to create a background process to monitor,
  # which will auto exit when "here" is removed.
  tail -f $mode here & pid=$!

  # Ensure that tail --pid=PID does not exit when PID is alive.
  returns_ 124 timeout 1 tail -f -s.1 --pid=$pid $mode here || fail=1

  cleanup_

  # Ensure that tail --pid=PID exits with success status when PID is dead.
  # Use an unlikely-to-be-live PID
  timeout 10 tail -f -s.1 --pid=$PID_T_MAX $mode empty
  ret=$?
  test $ret = 124 && skip_ "pid $PID_T_MAX present or tail too slow"
  test $ret = 0 || fail=1

  # Ensure tail doesn't wait for data when PID is dead
  returns_ 124 timeout 10 tail -f -s10 --pid=$PID_T_MAX $mode empty && fail=1
done

Exit $fail
