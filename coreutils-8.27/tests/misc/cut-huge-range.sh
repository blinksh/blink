#!/bin/sh
# Ensure that cut does not allocate mem for large ranges

# Copyright (C) 2012-2017 Free Software Foundation, Inc.

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
print_ver_ cut
getlimits_

vm=$(get_min_ulimit_v_ cut -b1 /dev/null) \
  || skip_ "this shell lacks ulimit support"
vm=$(($vm + 1000)) # avoid spurious failures

# sed script to subtract one from the input.
# Each input line should consist of a positive decimal number.
# Each output line's number is one less than the input's.
# There's no limit (other than line length) on the number's magnitude.
subtract_one='
  s/$/@/
  : again
  s/0@/@9/
  s/1@/0/
  s/2@/1/
  s/3@/2/
  s/4@/3/
  s/5@/4/
  s/6@/5/
  s/7@/6/
  s/8@/7/
  s/9@/8/
  t again
'

# Ensure we can cut up to our sentinel value.
# This is currently SIZE_MAX, but could be raised to UINTMAX_MAX
# if we didn't allocate memory for each line as a unit.
# Don't use expr to subtract one,
# since SIZE_MAX may exceed its maximum value.
CUT_MAX=$(echo $SIZE_MAX | sed "$subtract_one")

# From coreutils-8.10 through 8.20, this would make cut try to allocate
# a 256MiB bit vector.
(ulimit -v $vm && cut -b$CUT_MAX- /dev/null > err 2>&1) || fail=1

# Up to and including coreutils-8.21, cut would allocate possibly needed
# memory upfront.  Subsequently extra memory is no longer needed.
(ulimit -v $vm && cut -b1-$CUT_MAX /dev/null >> err 2>&1) || fail=1

# Explicitly disallow values above CUT_MAX
(ulimit -v $vm && returns_ 1 cut -b$SIZE_MAX /dev/null 2>/dev/null) || fail=1
(ulimit -v $vm && returns_ 1 cut -b$SIZE_OFLOW /dev/null 2>/dev/null) || fail=1

compare /dev/null err || fail=1

Exit $fail
