#!/bin/sh
# tail -f - would fail with the initial inotify implementation

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

echo line > in || framework_failure_
echo line > exp || framework_failure_

for mode in '' '---disable-inotify'; do
  > out || framework_failure_

  tail $mode -f $fastpoll < in > out 2> err & pid=$!

  # Wait up to 12.7s for output to appear:
  tail_re='line' retry_delay_ check_tail_output .1 7 ||
    { echo "$0: a: unexpected delay?"; cat out; fail=1; }

  # Ensure there was no error output.
  compare /dev/null err || fail=1

  cleanup_
done


# Before coreutils-8.26 this would induce an UMR under UBSAN
returns_ 1 timeout 10 tail -f - <&- 2>errt || fail=1
cat <<\EOF >exp || framework_failure_
tail: cannot fstat 'standard input'
tail: error reading 'standard input'
tail: no files remaining
tail: -
EOF
sed 's/\(tail:.*\):.*/\1/' errt > err || framework_failure_
compare exp err || fail=1


Exit $fail
