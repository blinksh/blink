#!/bin/sh
# exercise head -c

# Copyright (C) 2001-2017 Free Software Foundation, Inc.

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
print_ver_ head
getlimits_

vm=$(get_min_ulimit_v_ head -c1 /dev/null) \
  || skip_ "this shell lacks ulimit support"

# exercise the fix of 2001-08-18, based on test case from Ian Bruce
echo abc > in || framework_failure_
(head -c1; head -c1) < in > out || fail=1
case "$(cat out)" in
  ab) ;;
  *) fail=1 ;;
esac

# Test for a bug in coreutils 5.0.1 through 8.22.
printf 'abc\ndef\n' > in1 || framework_failure_
(dd bs=1 skip=1 count=0 status=none && head -c-4) < in1 > out1 || fail=1
case "$(cat out1)" in
  bc) ;;
  *) fail=1 ;;
esac

# Only allocate memory as needed.
# Coreutils <= 8.21 would allocate memory up front
# based on the value passed to -c
(ulimit -v $(($vm+8000)) && head --bytes=-$SSIZE_MAX < /dev/null) || fail=1

# Make sure it works on funny files in /proc and /sys.

for file in /proc/version /sys/kernel/profiling; do
  if test -r $file; then
    cp -f $file copy &&
    head -c -1 copy > exp1 || framework_failure_

    head -c -1 $file > out1 || fail=1
    compare exp1 out1 || fail=1
  fi
done

Exit $fail
