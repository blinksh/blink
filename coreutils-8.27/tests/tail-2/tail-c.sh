#!/bin/sh
# exercise tail -c

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
print_ver_ tail

# Make sure it works on funny files in /proc and /sys.

for file in /proc/version /sys/kernel/profiling; do
  if test -r $file; then
    cp -f $file copy &&
    tail -c -1 copy > exp1 || framework_failure_

    tail -c -1 $file > out1 || fail=1
    compare exp1 out1 || fail=1
  fi
done

Exit $fail
