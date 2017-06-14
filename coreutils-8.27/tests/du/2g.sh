#!/bin/sh
# Ensure that du can handle a 2GB file (i.e., a file of size 2^31 bytes)
# Before coreutils-5.93, on systems with a signed, 32-bit stat.st_blocks
# one of du's computations would overflow.

# Copyright (C) 2005-2017 Free Software Foundation, Inc.

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

# Creating a 2GB file counts as 'very expensive'.
very_expensive_

# Get number of free kilobytes on current partition, so we can
# skip this test if there is insufficient free space.
free_kb=$(df -k --output=avail . | tail -n1)
case "$free_kb" in
  [0-9]*) ;;
  *) skip_ "invalid size from df: $free_kb";;
esac

# Require about 3GB free.
min_kb=3000000
test $min_kb -lt $free_kb ||
{
  skip_ \
    "too little free space on current partition: $free_kb (need $min_kb KB)"
}

big=big

if ! fallocate -l2G $big; then
  rm -f $big
  {
    is_local_dir_ . || skip 'Not writing 2GB data to remote'
    for i in $(seq 100); do
      # Note: 2147483648 == 2^31. Print floor(2^31/100) per iteration.
      printf %21474836s x || fail=1
    done
    # After the final iteration, append the remaining 48 bytes.
    printf %48s x || fail=1
  } > $big || fail=1
fi

# The allocation may be done asynchronously (BTRFS for example)
sync $big || framework_failure_

du -k $big > out1 || fail=1
rm -f $big
sed 's/^2[0-9][0-9][0-9][0-9][0-9][0-9]	'$big'$/~2M/' out1 > out

cat <<\EOF > exp || fail=1
~2M
EOF

compare exp out || fail=1

Exit $fail
