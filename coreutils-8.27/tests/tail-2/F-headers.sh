#!/bin/sh
# Ensure tail -F distinguishes output with the correct headers
# Between coreutils 7.5 and 8.23 inclusive, 'tail -F ...' would
# not output headers for or created/renamed files in certain cases.

# Copyright (C) 2015-2017 Free Software Foundation, Inc.

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

check_tail_output()
{
  local delay="$1"
  grep "$tail_re" out ||
    { sleep $delay; return 1; }
}

# Terminate any background tail process
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

# Speedup the non inotify case
fastpoll='-s.1 --max-unchanged-stats=1'

for mode in '' '---disable-inotify'; do
  rm -f a b out

  tail $mode -F $fastpoll a b > out 2>&1 & pid=$!

  # Wait up to 12.7s for tail to start.
  tail_re="cannot open 'b'" retry_delay_ check_tail_output .1 7 ||
    { cat out; fail=1; }

  echo x > a
  # Wait up to 12.7s for a's header to appear in the output:
  tail_re='==> a <==' retry_delay_ check_tail_output .1 7 ||
    { echo "$0: a: unexpected delay?"; cat out; fail=1; }

  echo y > b
  # Wait up to 12.7s for b's header to appear in the output:
  tail_re='==> b <==' retry_delay_ check_tail_output .1 7 ||
    { echo "$0: b: unexpected delay?"; cat out; fail=1; }

  cleanup_
done

Exit $fail
