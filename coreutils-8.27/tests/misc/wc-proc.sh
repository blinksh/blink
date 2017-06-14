#!/bin/sh
# Test wc on /proc and /sys files.

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
print_ver_ wc

# Ensure we read() /proc files to determine content length
for file in /proc/version /sys/kernel/profiling; do
  if test -r $file; then
    cp -f $file copy &&
    wc -c < copy > exp1 || framework_failure_

    wc -c < $file > out1 || fail=1
    compare exp1 out1 || fail=1
  fi
done

# Ensure we handle cases where we don't read()
truncate -s 2 no_read || framework_failure_
# read() used when multiple of page size
truncate -s 1048576 do_read || framework_failure_
wc -c no_read do_read > out || fail=1
cat <<\EOF > exp
      2 no_read
1048576 do_read
1048578 total
EOF
compare exp out || fail=1

Exit $fail
