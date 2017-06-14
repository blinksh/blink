#!/bin/sh
# This variant of 'assert' would get a Uninit Mem Read reliably in 2.0.9.
# Due to a race condition in the test, the 'assert' script would get
# the UMR on Solaris only some of the time, and not at all on Linux/GNU.

# Copyright (C) 2000-2017 Free Software Foundation, Inc.

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
  rm -f a foo out
  touch a || framework_failure_

  tail $mode $fastpoll -F a foo > out 2>&1 & pid=$!

  # Wait up to 12.7s for tail to start.
  echo x > a || framework_failure_
  tail_re='^x$' retry_delay_ check_tail_output .1 7 ||
    { cat out; fail=1; break; }

  # Wait up to 12.7s for tail to notice new foo file
  ok='ok ok ok'
  echo "$ok" > foo || framework_failure_
  tail_re="^$ok$" retry_delay_ check_tail_output .1 7 ||
    { echo "$0: foo: unexpected delay?"; cat out; fail=1; break; }

  cleanup_
done

Exit $fail
