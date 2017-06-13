#!/bin/sh
# Verify that 'od -j N' skips N bytes of input.

# Copyright 2014-2017 Free Software Foundation, Inc.

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
print_ver_ od

for file in ${srcdir=.}/tests/init.sh /proc/version /sys/kernel/profiling; do
  test -r $file || continue

  cp -f $file copy &&
  bytes=$(wc -c < copy) || framework_failure_

  od -An $file > exp || fail=1
  od -An -j $bytes $file $file > out || fail=1
  compare exp out || fail=1

  od -An -j 4096 copy copy > exp1 2> experr1; expstatus=$?
  od -An -j 4096 $file $file > out1 2> err1; status=$?
  test $status -eq $expstatus || fail=1
  compare exp1 out1 || fail=1
  compare experr1 err1 || fail=1
done

Exit $fail
