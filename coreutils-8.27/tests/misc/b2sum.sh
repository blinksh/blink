#!/bin/sh
# 'b2sum' tests

# Copyright (C) 2016-2017 Free Software Foundation, Inc.

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
print_ver_ b2sum

# Ensure we can --check the --tag format we produce
rm check.b2sum
for i in 'a' ' b' '*c' '44' ' '; do
  echo "$i" > "$i"
  for l in 0 128; do
    b2sum -l $l --tag "$i" >> check.b2sum
  done
done
# Note -l is inferred from the tags in the mixed format file
b2sum --strict -c check.b2sum || fail=1
# Also ensure the openssl tagged variant works
sed 's/ //; s/ =/=/' < check.b2sum > openssl.b2sum || framework_failure_
b2sum --strict -c openssl.b2sum || fail=1

# Ensure we can check non tagged format
for l in 0 128; do
  b2sum -l $l /dev/null | tee -a check.vals > check.b2sum
  b2sum -l $l --strict -c check.b2sum || fail=1
  b2sum --strict -c check.b2sum || fail=1
done

# Ensure the checksum values are correct.  The reference
# check.vals was created with the upstream SSE reference implementation.
b2sum -l 128 check.vals > out || fail=1
printf '%s\n' '796485dd32fe9b754ea5fd6c721271d9  check.vals' > exp
compare exp out || fail=1

Exit $fail
