#!/bin/sh
# Make sure that 'tail -n0 -f' and 'tail -c0 -f' sleep
# rather than doing what amounted to a busy-wait.

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

# This bug was fixed for 5.0.91
# It skips the test if your system lacks a /proc/$pid/status
# file, or if its contents don't look right.

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ tail

require_proc_pid_status_

touch empty || framework_failure_
echo anything > nonempty || framework_failure_

# First verify that -[nc]0 without -f, exit without reading
touch unreadable || framework_failure_
chmod 0 unreadable || framework_failure_
tail -c0 unreadable || fail=1
tail -n0 unreadable || fail=1

# Terminate any background tail process
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

for mode in '' '---disable-inotify'; do
  for file in empty nonempty; do
    for c_or_n in c n; do
      tail --sleep=4 -${c_or_n} 0 -f $mode $file & pid=$!
      tail_sleeping()
      {
        local delay="$1"; sleep $delay
        state=$(get_process_status_ $pid)
        case $state in
          S*) ;;
          *) return 1;;
        esac
      }
      # Wait up to 1.5s for tail to sleep
      retry_delay_ tail_sleeping .1 4 ||
        { echo $0: process in unexpected state: $state >&2; fail=1; }
      cleanup_
    done
  done
done

Exit $fail
