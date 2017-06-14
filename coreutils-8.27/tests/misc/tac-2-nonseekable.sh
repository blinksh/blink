#!/bin/sh
# ensure that tac works with non-seekable or quasi-seekable inputs

# Copyright (C) 2011-2017 Free Software Foundation, Inc.

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
print_ver_ tac

echo x | tac - - > out 2> err || fail=1
echo x > exp || fail=1
compare exp out || fail=1
compare /dev/null err || fail=1

# Make sure it works on funny files in /proc and /sys.

for file in /proc/version /sys/kernel/profiling; do
  if test -r $file; then
    cp -f $file copy &&
    tac copy > exp1 || framework_failure_

    tac $file > out1 || fail=1
    compare exp1 out1 || fail=1
  fi
done

# This failed due to heap corruption from v8.15-v8.25 inclusive.
returns_ 1 tac - - <&- 2>err || fail=1

Exit $fail
