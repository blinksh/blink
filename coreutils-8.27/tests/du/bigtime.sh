#!/bin/sh
# Exercise du on a file with a big timestamp.

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
print_ver_ du

export LC_ALL=C
export TZ=UTC0

# 2**63 - 1
bignum=9223372036854775807

touch -d @$bignum future 2>/dev/null &&
future_time=$(ls -l future) &&
case "$future_time" in
*" $bignum "*)
  : ;;
*' Dec  4  300627798676 '*)
  skip_ "file system and localtime both handle big timestamps" ;;
*)
  skip_ "file system or localtime mishandles big timestamps:" \
      "$future_time" ;;
esac || skip_ "file system cannot represent big timestamps"

printf "0\t$bignum\tfuture\n" > exp || framework_failure_
printf "du: time '$bignum' is out of range\n" > err_ok || framework_failure_

du --time future >out 2>err || fail=1

# On some systems an empty file occupies 4 blocks.
# Map the number of blocks to 0.
sed 's/^[0-9][0-9]*/0/' out > k && mv k out

compare exp out || fail=1
compare err err_ok || fail=1

Exit $fail
