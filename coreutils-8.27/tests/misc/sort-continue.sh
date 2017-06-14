#!/bin/sh
# Tests for file descriptor exhaustion.

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
print_ver_ sort

# Skip the test when running under valgrind.
( ulimit -n 6; sort 3<&- 4<&- 5<&- < /dev/null ) \
  || skip_ 'fd-limited sort failed; are you running under valgrind?'

for i in $(seq 31); do
  echo $i | tee -a in > __test.$i || framework_failure_
done

# glob before ulimit to avoid issues on bash 3.2 on OS X 10.6.8 at least
test_files=$(echo __test.*)

(
 ulimit -n 6
 sort -n -m $test_files 3<&- 4<&- 5<&- < /dev/null > out
) &&
compare in out ||
  { fail=1; echo 'file descriptor exhaustion not handled' 1>&2; }

echo 32 | tee -a in > in1
(
 ulimit -n 6
 sort -n -m $test_files - 3<&- 4<&- 5<&- < in1 > out
) &&
compare in out || { fail=1; echo 'stdin not handled properly' 1>&2; }

Exit $fail
