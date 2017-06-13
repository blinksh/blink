#!/bin/sh
# test splitting into 3 chunks

# Copyright (C) 2010-2017 Free Software Foundation, Inc.

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
print_ver_ split

# N can be greater than the file size
# in which case no data is extracted, or empty files are written
split -n 10 /dev/null || fail=1
test "$(stat -c %s x* | uniq -c | sed 's/^ *//; s/ /x/')" = "10x0" || fail=1
rm -f x??

# When extracting K of N where N > file size
# no data is extracted, and no files are written
split -n 2/3 /dev/null || fail=1
returns_ 1 stat x?? 2>/dev/null || fail=1

# Ensure --elide-empty-files is honored
split -e -n 10 /dev/null || fail=1
returns_ 1 stat x?? 2>/dev/null || fail=1

printf '1\n2\n3\n4\n5\n' > input || framework_failure_

for file in input /proc/version /sys/kernel/profiling; do
  test -f $file || continue

  split -n 3 $file > out || fail=1
  split -n 1/3 $file > b1 || fail=1
  split -n 2/3 $file > b2 || fail=1
  split -n 3/3 $file > b3 || fail=1

  case $file in
    input)
      printf '1\n2' > exp-1
      printf '\n3\n' > exp-2
      printf '4\n5\n' > exp-3

      compare exp-1 xaa || fail=1
      compare exp-2 xab || fail=1
      compare exp-3 xac || fail=1
      ;;
  esac

  compare xaa b1 || fail=1
  compare xab b2 || fail=1
  compare xac b3 || fail=1
  cat xaa xab xac | compare - $file || fail=1
  test -f xad && fail=1
done

Exit $fail
