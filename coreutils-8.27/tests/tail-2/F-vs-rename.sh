#!/bin/sh
# Demonstrate that tail -F works when renaming the tailed files.
# Between coreutils 7.5 and 8.2 inclusive, 'tail -F a b' would
# stop tracking additions to b after 'mv a b'.

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
  touch a b || framework_failure_

  tail $mode -F $fastpoll a b > out 2>&1 & pid=$!

  # Wait up to 12.7s for tail to start.
  echo x > a
  tail_re='^x$' retry_delay_ check_tail_output .1 7 || { cat out; fail=1; }

  mv a b || framework_failure_

  # Wait 12.7s for this diagnostic:
  # tail: 'a' has become inaccessible: No such file or directory
  tail_re='inaccessible' retry_delay_ check_tail_output .1 7 ||
    { cat out; fail=1; }

  echo x > a
  # Wait up to 12.7s for this to appear in the output:
  # "tail: '...' has appeared;  following new file"
  tail_re='has appeared' retry_delay_ check_tail_output .1 7 ||
    { echo "$0: a: unexpected delay?"; cat out; fail=1; }

  echo y >> b
  # Wait up to 12.7s for "y" to appear in the output:
  tail_f_vs_rename_2() {
    local delay="$1"
    tr '\n' @ < out | grep '@@==> b <==@y@$' > /dev/null ||
      { sleep $delay; return 1; }
  }
  retry_delay_ tail_f_vs_rename_2 .1 7 ||
    { echo "$0: b: unexpected delay?"; cat out; fail=1; }

  echo z >> a
  # Wait up to 12.7s for "z" to appear in the output:
  tail_f_vs_rename_3() {
    local delay="$1"
    tr '\n' @ < out | grep '@@==> a <==@z@$' > /dev/null ||
      { sleep $delay; return 1; }
  }
  retry_delay_ tail_f_vs_rename_3 .1 7 ||
    { echo "$0: a: unexpected delay?"; cat out; fail=1; }

  cleanup_
done

Exit $fail
