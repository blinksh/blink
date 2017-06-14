#!/bin/sh
# test splitting into round-robin chunks

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
split -n r/10 /dev/null || fail=1
test "$(stat -c %s x* | uniq -c | sed 's/^ *//; s/ /x/')" = "10x0" || fail=1
rm x??

# Ensure --elide-empty-files is honored
split -e -n r/10 /dev/null || fail=1
stat x?? 2>/dev/null && fail=1

printf '1\n2\n3\n4\n5\n' > in || framework_failure_

split -n r/3 in > out || fail=1
compare /dev/null out || fail=1

split -n r/1/3 in > r1 || fail=1
split -n r/2/3 in > r2 || fail=1
split -n r/3/3 in > r3 || fail=1

printf '1\n4\n' > exp-1
printf '2\n5\n' > exp-2
printf '3\n' > exp-3

compare exp-1 xaa || fail=1
compare exp-2 xab || fail=1
compare exp-3 xac || fail=1
compare exp-1 r1 || fail=1
compare exp-2 r2 || fail=1
compare exp-3 r3 || fail=1
test -f xad && fail=1

# Test input without trailing \n
printf '1\n2\n3\n4\n5' | split -n r/2/3 > out
printf '2\n5' > exp
compare exp out || fail=1

# Ensure we fall back to appending to a file at a time
# if we hit the limit for the number of open files.
rm x*
(ulimit -n 20 && yes | head -n90 | split -n r/30 ) || fail=1
test "$(stat -c %s x* | uniq -c | sed 's/^ *//; s/ /x/')" = "30x6" || fail=1

Exit $fail
