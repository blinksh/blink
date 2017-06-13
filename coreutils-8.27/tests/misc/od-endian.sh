#!/bin/sh
# verify that od --endian works properly

# Copyright (C) 2014-2017 Free Software Foundation, Inc.

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

in='0123456789abcdef'

NL='
'

# rev(1) is not generally available, so here's a simplistic
# implementation sufficient for our purposes.
rev() {
  while read line; do
    printf '%s' "$line" | sed "s/./&\\$NL/g" | tac | paste -s -d ''
  done
}

in_swapped() { printf '%s' "$in" | sed "s/.\{$1\}/&\\$NL/g" | rev |tr -d '\n'; }

for e in little big; do
  test $e = little && eo=big || eo=little
  for s in 1 2 4 8 16; do
    for t in x f; do
      od -t $t$s --endian=$e /dev/null > /dev/null 2>&1 || continue
      printf '%s' "$in" | od -An -t $t$s --endian=$e  > out1
      in_swapped  "$s"  | od -An -t $t$s --endian=$eo > out2
      compare out1 out2 || fail=1
    done
  done
done

Exit $fail
