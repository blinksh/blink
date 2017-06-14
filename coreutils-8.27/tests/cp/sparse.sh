#!/bin/sh
# Test cp --sparse=always

# Copyright (C) 2006-2017 Free Software Foundation, Inc.

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
print_ver_ cp
require_sparse_support_

# Create a sparse file.
# It has to be at least 128K in order to be sparse on some systems.
# Make its size one larger than 128K, in order to tickle the
# bug in coreutils-6.0.
size=$(expr 128 \* 1024 + 1)
dd bs=1 seek=$size of=sparse < /dev/null 2> /dev/null || framework_failure_


cp --sparse=always sparse copy || fail=1

# Ensure that the copy has the same block count as the original.
test $(stat --printf %b copy) -le $(stat --printf %b sparse) || fail=1

# Ensure that --sparse={always,never} with --reflink fail.
returns_ 1 cp --sparse=always --reflink sparse copy || fail=1
returns_ 1 cp --sparse=never --reflink sparse copy || fail=1


# Ensure we handle sparse/non-sparse transitions correctly
maxn=128 # how many $hole_size chunks per file
hole_size=$(stat -c %o copy)
dd if=/dev/zero bs=$hole_size count=$maxn of=zeros || framework_failure_
tr '\0' 'U' < zeros > nonzero || framework_failure_

for pattern in 1 0; do
  test "$pattern" = 1 && pattern="$(printf '%s\n%s' nonzero zeros)"
  test "$pattern" = 0 && pattern="$(printf '%s\n%s' zeros nonzero)"

  for n in 1 2 4 11 32 $maxn; do
    parts=$(expr $maxn / $n)

    rm -f sparse.in

    # Generate non sparse file for copying with alternating
    # hole/data patterns of size n * $hole_size
    for i in $(yes "$pattern" | head -n$parts); do
      dd iflag=fullblock if=$i of=sparse.in conv=notrunc oflag=append \
         bs=$hole_size count=$n status=none || framework_failure_
    done

    cp --sparse=always sparse.in sparse.out   || fail=1 # non sparse input
    cp --sparse=always sparse.out sparse.out2 || fail=1 # sparse input

    cmp sparse.in sparse.out || fail=1
    cmp sparse.in sparse.out2 || fail=1

    ls -lsh sparse.*
  done
done

Exit $fail
