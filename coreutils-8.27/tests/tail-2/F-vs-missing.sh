#!/bin/sh
# demonstrate that tail -F works for currently missing dirs
# Before coreutils-8.6, tail -F missing/file would not
# notice any subsequent availability of the missing/file.

# Copyright (C) 2010-2017 Free Software Foundation, Inc.

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
  grep "$tail_re" out > /dev/null ||
    { sleep $delay; return 1; }
}

# Terminate any background tail process
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

# Speedup the non inotify case
fastpoll='-s.1 --max-unchanged-stats=1'

for mode in '' '---disable-inotify'; do
  rm -rf out missing

  tail $mode -F $fastpoll missing/file > out 2>&1 & pid=$!

  # Wait up to 12.7s for tail to start with diagnostic:
  # tail: cannot open 'missing/file' for reading: No such file or directory
  tail_re='cannot open' retry_delay_ check_tail_output .1 7 ||
    { cat out; fail=1; }

  mkdir missing || framework_failure_
  (cd missing && echo x > file) || framework_failure_

  # Wait up to 12.7s for this to appear in the output:
  # "tail: '...' has appeared;  following new file"
  tail_re='has appeared' retry_delay_ check_tail_output .1 7 ||
    { echo "$0: file: unexpected delay?"; cat out; fail=1; }

  cleanup_
done


Exit $fail
