#!/bin/sh
# verify that multiple -t specifiers to od align well
# This would fail before coreutils-6.13.

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
print_ver_ od

# Choose 48 bytes for the input, as that is lcm for 1, 2, 4, 8, 12, 16;
# we don't anticipate any other native object size on modern hardware.
seq 19 > in || framework_failure_
test $(wc -c < in) -eq 48 || framework_failure_


list='a c dC dS dI dL oC oS oI oL uC uS uI uL xC xS xI xL fF fD fL'
for format1 in $list; do
  for format2 in $list; do
    od -An -t${format1}z -t${format2}z in > out-raw || fail=1
    linewidth=$(head -n1 out-raw | wc -c)
    linecount=$(wc -l < out-raw)
    echo $format1 $format2 $(wc -c < out-raw) >> out
    echo $format1 $format2 $(expr $linewidth '*' $linecount) >> exp
  done
done

compare exp out || fail=1

Exit $fail
