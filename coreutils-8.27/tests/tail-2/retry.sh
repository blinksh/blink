#!/bin/sh
# Exercise tail's behavior regarding missing files with/without --retry.

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

# Speedup the non inotify case
fastpoll='-s.1 --max-unchanged-stats=1'

# === Test:
# Retry without --follow results in a warning.
touch file
tail --retry file > out 2>&1 || fail=1
[ "$(countlines_)" = 1 ]                     || { cat out; fail=1; }
grep -F 'tail: warning: --retry ignored' out || { cat out; fail=1; }

# === Test:
# The same with a missing file: expect error message and exit 1.
returns_ 1 tail --retry missing > out 2>&1 || fail=1
[ "$(countlines_)" = 2 ]                     || { cat out; fail=1; }
grep -F 'tail: warning: --retry ignored' out || { cat out; fail=1; }

for mode in '' '---disable-inotify'; do

# === Test:
# Ensure that "tail --retry --follow=name" waits for the file to appear.
# Clear 'out' so that we can check its contents without races
>out                            || framework_failure_
timeout 10 \
  tail $mode $fastpoll --follow=name --retry missing >out 2>&1 & pid=$!
# Wait for "cannot open" error.
retry_delay_ wait4lines_ .1 6 1 || { cat out; fail=1; }
echo "X" > missing              || framework_failure_
# Wait for the expected output.
retry_delay_ wait4lines_ .1 6 3 || { cat out; fail=1; }
cleanup_
# Expect 3 lines in the output file.
[ "$(countlines_)" = 3 ]   || { fail=1; cat out; }
grep -F 'cannot open' out  || { fail=1; cat out; }
grep -F 'has appeared' out || { fail=1; cat out; }
grep '^X$' out             || { fail=1; cat out; }
rm -f missing out          || framework_failure_

# === Test:
# Ensure that "tail --retry --follow=descriptor" waits for the file to appear.
# tail-8.21 failed at this (since the implementation of the inotify support).
timeout 10 \
  tail $mode $fastpoll --follow=descriptor --retry missing >out 2>&1 & pid=$!
# Wait for "cannot open" error.
retry_delay_ wait4lines_ .1 6 2 || { cat out; fail=1; }
echo "X1" > missing             || framework_failure_
# Wait for the expected output.
retry_delay_ wait4lines_ .1 6 4 || { cat out; fail=1; }
# Ensure truncation is detected
# tail-8.25 failed at this (as assumed non file and went into blocking mode)
echo "X" > missing             || framework_failure_
retry_delay_ wait4lines_ .1 6 6 || { cat out; fail=1; }
cleanup_
[ "$(countlines_)" = 6 ]   || { fail=1; cat out; }
grep -F 'retry only effective for the initial open' out \
                           || { fail=1; cat out; }
grep -F 'cannot open' out  || { fail=1; cat out; }
grep -F 'has appeared' out || { fail=1; cat out; }
grep '^X1$' out            || { fail=1; cat out; }
grep -F 'file truncated' out || { fail=1; cat out; }
grep '^X$' out            || { fail=1; cat out; }
rm -f missing out          || framework_failure_

# === Test:
# Ensure that tail --follow=descriptor --retry exits when the file appears
# untailable. Expect exit status 1.
timeout 10 \
  tail $mode $fastpoll --follow=descriptor --retry missing >out 2>&1 & pid=$!
# Wait for "cannot open" error.
retry_delay_ wait4lines_ .1 6 2 || { cat out; fail=1; }
mkdir missing                   || framework_failure_  # Create untailable
# Wait for the expected output.
retry_delay_ wait4lines_ .1 6 4 || { cat out; fail=1; }
wait $pid
rc=$?
[ "$(countlines_)" = 4 ]                       || { fail=1; cat out; }
grep -F 'retry only effective for the initial open' out \
                                               || { fail=1; cat out; }
grep -F 'cannot open' out                      || { fail=1; cat out; }
grep -F 'replaced with an untailable file' out || { fail=1; cat out; }
grep -F 'no files remaining' out               || { fail=1; cat out; }
[ $rc = 1 ]                                    || { fail=1; cat out; }
rm -fd missing out                             || framework_failure_

# === Test:
# Ensure that --follow=descriptor (without --retry) does *not* try
# to open a file after an initial fail, even when there are other
# tailable files.  This was an issue in <= 8.25.
touch existing || framework_failure_
tail $mode $fastpoll --follow=descriptor missing existing >out 2>&1 & pid=$!
retry_delay_ wait4lines_ .1 6 2  || { cat out; fail=1; }
[ "$(countlines_)" = 2 ]         || { fail=1; cat out; }
grep -F 'cannot open' out        || { fail=1; cat out; }
echo "Y" > missing               || framework_failure_
echo "X" > existing              || framework_failure_
retry_delay_ wait4lines_ .1 6 3  || { cat out; fail=1; }
[ "$(countlines_)" = 3 ]         || { fail=1; cat out; }
grep '^X$' out                   || { fail=1; cat out; }
grep '^Y$' out                   && { fail=1; cat out; }
cleanup_
rm -f missing out existing       || framework_failure_

# === Test:
# Ensure that --follow=descriptor (without --retry) does *not wait* for the
# file to appear.  Expect 2 lines in the output file ("cannot open" +
# "no files remaining") and exit status 1.
returns_ 1 tail $mode --follow=descriptor missing >out 2>&1 || fail=1
[ "$(countlines_)" = 2 ]         || { fail=1; cat out; }
grep -F 'cannot open' out        || { fail=1; cat out; }
grep -F 'no files remaining' out || { fail=1; cat out; }
rm -f out                        || framework_failure_

# === Test:
# Likewise for --follow=name (without --retry).
returns_ 1 tail $mode --follow=name missing >out 2>&1 || fail=1
[ "$(countlines_)" = 2 ]         || { fail=1; cat out; }
grep -F 'cannot open' out        || { fail=1; cat out; }
grep -F 'no files remaining' out || { fail=1; cat out; }
rm -f out                        || framework_failure_

# === Test:
# Ensure that tail -F retries when the file is initially untailable.
if ! cat . >/dev/null; then
mkdir untailable || framework_failure_
timeout 10 \
  tail $mode $fastpoll -F untailable >out 2>&1 & pid=$!
# Wait for "cannot follow" error.
retry_delay_ wait4lines_ .1 6 2 || { cat out; fail=1; }
{ rmdir untailable; echo foo > untailable; }   || framework_failure_
# Wait for the expected output.
retry_delay_ wait4lines_ .1 6 4 || { cat out; fail=1; }
cleanup_
[ "$(countlines_)" = 4 ]                       || { fail=1; cat out; }
grep -F 'cannot follow' out                    || { fail=1; cat out; }
# The first is the common case, "has appeared" arises with slow rmdir.
grep -E 'become accessible|has appeared' out   || { fail=1; cat out; }
grep -F 'giving up' out                        && { fail=1; cat out; }
grep -F 'foo' out                              || { fail=1; cat out; }
rm -fd untailable out                          || framework_failure_
fi

done

Exit $fail
