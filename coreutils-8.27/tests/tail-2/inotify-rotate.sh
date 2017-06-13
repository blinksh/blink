#!/bin/sh
# ensure that tail -F handles rotation

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

grep '^#define HAVE_INOTIFY 1' "$CONFIG_HEADER" >/dev/null \
  || expensive_

check_tail_output()
{
  local delay="$1"
  grep "$tail_re" out > /dev/null ||
    { sleep $delay; return 1; }
}

# Wait up to 25.5 seconds for grep REGEXP 'out' to succeed.
grep_timeout() { tail_re="$1" retry_delay_ check_tail_output .1 8; }

# Terminate any background tail process
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

cleanup_fail()
{
  cat out
  warn_ $1
  cleanup_
  fail=1
}

# Speedup the non inotify case
fastpoll='-s.1 --max-unchanged-stats=1'

# Perform at least this many iterations, because on multi-core systems
# the offending sequence of events can be surprisingly uncommon.
# See: http://lists.gnu.org/archive/html/bug-coreutils/2009-11/msg00213.html
for i in $(seq 50); do
    echo $i
    rm -f k x out

    # Normally less than a second is required here, but with heavy load
    # and a lot of disk activity, even 20 seconds is insufficient, which
    # leads to this timeout killing tail before the "ok" is written below.
    >k && >x || framework_failure_ failed to initialize files
    timeout 60 tail $fastpoll -F k > out 2>&1 & pid=$!

    echo 'tailed' > k;
    # wait for 'tailed' to appear in out
    grep_timeout 'tailed' || { cleanup_fail 'failed to find "tailed"'; break; }

    mv x k
    # wait for tail to detect the rename
    grep_timeout 'tail:' || { cleanup_fail 'failed to detect rename'; break; }

    echo ok >> k
    # wait for "ok" to appear in 'out'
    grep_timeout 'ok' || { cleanup_fail 'failed to detect echoed ok'; break; }

    cleanup_
done

Exit $fail
