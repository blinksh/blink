#!/bin/sh
# Exercise an abort-inducing flaw in inotify-enabled tail -F.

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

# 9 is a magic number, related to internal details of tail.c and hash.c
n=9
seq $n | xargs touch || framework_failure_

check_tail_output()
{
  local delay="$1"
  grep "$tail_re" out > /dev/null ||
    { sleep $delay; return 1; }
}

# Terminate any background tail process
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

# Speedup the non inotify case
fastpoll='-s.1 --max-unchanged-stats=1'

for mode in '' '---disable-inotify'; do
  rm -f out

  tail $mode $fastpoll -qF $(seq $n) > out 2>&1 & pid=$!

  # Wait up to 12.7s for tail to start
  echo x > $n
  tail_re='^x$' retry_delay_ check_tail_output .1 7 ||
    { cat out; fail=1; }

  mv 1 f || framework_failure_

  # Wait 12.7s for this diagnostic:
  # tail: '1' has become inaccessible: No such file or directory
  tail_re='inaccessible' retry_delay_ check_tail_output .1 7 ||
    { cat out; fail=1; }

  # Trigger the bug.  Before the fix, this would provoke the abort.
  echo a > 1 || framework_failure_

  # Wait up to 6.3s for the "tail: '1' has appeared; ..." message
  # (or for the buggy tail to die)
  tail_re='has appeared' retry_delay_ check_tail_output .1 6 ||
    { cat out; fail=1; }

  # Double check that tail hasn't aborted
  kill -0 $pid || fail=1

  cleanup_
done


Exit $fail
