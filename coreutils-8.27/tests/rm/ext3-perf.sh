#!/bin/sh
# ensure that "rm -rf DIR-with-many-entries" is not O(N^2)

# Copyright (C) 2008-2017 Free Software Foundation, Inc.

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
print_ver_ rm

very_expensive_

# Using rm -rf to remove a 400k-entry directory takes:
# - 9 seconds with the patch, on a 2-yr-old system
# - 350 seconds without the patch, on a high-end system (disk 20-30% faster)
threshold_seconds=60

# The number of entries in our test directory.
n=400000

# Choose a value that is large enough to ensure an accidentally
# regressed rm would require much longer than $threshold_seconds to remove
# the directory.  With n=400k, pre-patch GNU rm would require about 350
# seconds even on a fast disk.  On a relatively modern system, the
# patched version of rm requires about 10 seconds, so even if you
# choose to enable very expensive tests with a disk that is much slower,
# the test should still succeed.

# Skip unless "." is on an ext[34] file system.
# FIXME-maybe: try to find a suitable file system or allow
# the user to specify it via an envvar.
df -T -t ext3 -t ext4dev -t ext4 . \
  || skip_ 'this test runs only on an ext3 or ext4 file system'

# Skip if there are too few inodes free.  Require some slack.
free_inodes=$(stat -f --format=%d .) || framework_failure_
min_free_inodes=$(expr 12 \* $n / 10)
test $min_free_inodes -lt $free_inodes \
  || skip_ "too few free inodes on '.': $free_inodes;" \
      "this test requires at least $min_free_inodes"

ok=0
start=$(date +%s)
mkdir d &&
  cd d &&
    seq $n | xargs touch &&
    test -f 1 &&
    test -f $n &&
  cd .. &&
  ok=1
test $ok = 1 || framework_failure_
setup_duration=$(expr $(date +%s) - $start)
echo creating a $n-entry directory took $setup_duration seconds

# If set-up took longer than the default $threshold_seconds,
# use the longer set-up duration as the limit.
test $threshold_seconds -lt $setup_duration \
  && threshold_seconds=$setup_duration

start=$(date +%s)
timeout ${threshold_seconds}s rm -rf d; err=$?
duration=$(expr $(date +%s) - $start)

case $err in
  124) fail=1; echo rm took longer than $threshold_seconds seconds;;
  0) ;;
  *) fail=1;;
esac

echo removing a $n-entry directory took $duration seconds

Exit $fail
