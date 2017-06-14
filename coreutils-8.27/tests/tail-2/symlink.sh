#!/bin/sh
# Ensure tail tracks symlinks properly.

# Copyright (C) 2013-2017 Free Software Foundation, Inc.

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

# Function to count number of lines from tail
# while ignoring transient errors due to resource limits
countlines_ ()
{
  grep -Ev 'inotify (resources exhausted|cannot be used)' out | wc -l
}

# Function to check the expected line count in 'out'.
# Called via retry_delay_().  Sleep some time - see retry_delay_() - if the
# line count is still smaller than expected.
wait4lines_ ()
{
  local delay=$1
  local elc=$2   # Expected line count.
  [ "$(countlines_)" -ge "$elc" ] || { sleep $delay; return 1; }
}

# Terminate any background tail process
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

# speedup non inotify case
fastpoll='-s.1 --max-unchanged-stats=1'

# Ensure changing targets of cli specified symlinks are handled.
# Prior to v8.22, inotify would fail to recognize changes in the targets.
# Clear 'out' so that we can check its contents without races.
>out                            || framework_failure_
ln -nsf target symlink          || framework_failure_
timeout 10 tail $fastpoll -F symlink >out 2>&1 & pid=$!
# Wait for "cannot open..."
retry_delay_ wait4lines_ .1 6 1 || { cat out; fail=1; }
echo "X" > target               || framework_failure_
# Wait for the expected output.
retry_delay_ wait4lines_ .1 6 3 || { cat out; fail=1; }
cleanup_
# Expect 3 lines in the output file.
[ "$(countlines_)" = 3 ]   || { fail=1; cat out; }
grep -F 'cannot open' out  || { fail=1; cat out; }
grep -F 'has appeared' out || { fail=1; cat out; }
grep '^X$' out             || { fail=1; cat out; }
rm -f target out           || framework_failure_

# Ensure we correctly handle the source symlink itself changing.
# I.e., that we don't operate solely on the targets.
# Clear 'out' so that we can check its contents without races.
>out                            || framework_failure_
echo "X1" > target1             || framework_failure_
ln -nsf target1 symlink         || framework_failure_
timeout 10 tail $fastpoll -F symlink >out 2>&1 & pid=$!
# Wait for the expected output.
retry_delay_ wait4lines_ .1 6 1 || { cat out; fail=1; }
ln -nsf target2 symlink         || framework_failure_
# Wait for "become inaccess..."
retry_delay_ wait4lines_ .1 6 2 || { cat out; fail=1; }
echo "X2" > target2             || framework_failure_
# Wait for the expected output.
retry_delay_ wait4lines_ .1 6 4 || { cat out; fail=1; }
cleanup_
# Expect 4 lines in the output file.
[ "$(countlines_)" = 4 ]    || { fail=1; cat out; }
grep -F 'become inacce' out || { fail=1; cat out; }
grep -F 'has appeared' out  || { fail=1; cat out; }
grep '^X1$' out             || { fail=1; cat out; }
grep '^X2$' out             || { fail=1; cat out; }
rm -f target1 target2 out   || framework_failure_

# Note other symlink edge cases are currently just diagnosed
# rather than being handled.  I.e., if you specify a missing item,
# or existing file that later change to a symlink, if inotify
# is in use, you'll get a diagnostic saying that link will
# no longer be tailed.

Exit $fail
