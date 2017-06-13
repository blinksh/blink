#!/bin/sh
# Ensure that df /dev/loop0 errors out if overmounted by another device

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
print_ver_ df
require_root_

cwd=$(pwd)
cleanup_() { cd /; umount "$cwd/mnt"; umount "$cwd/mnt"; }

skip=0

# Create 2 file systems
for i in 1 2; do
  dd if=/dev/zero of=blob$i bs=8192 count=200 > /dev/null 2>&1 \
                                             || skip=1
  mkfs -t ext2 -F blob$i \
    || skip_ "failed to create ext2 file system"
done

# Mount both at the same place (eclipsing the first)
mkdir mnt                                    || skip=1
mount -oloop blob1 mnt                       || skip=1
eclipsed_dev=$(df --o=source mnt | tail -n1) || skip=1
mount -oloop blob2 mnt                       || skip=1

test $skip = 1 \
  && skip_ "insufficient mount/ext2 support"

df . || skip_ "failed to lookup the device for the current dir"

echo "df: cannot access '$eclipsed_dev': over-mounted by another device" > exp

# We should get an error for the eclipsed device and continue
df $eclipsed_dev . > out 2> err && fail=1

# header and single entry in output
test $(wc -l < out) = 2 || fail=1

compare exp err || fail=1

test "$fail" = 1 && dump_mount_list_

Exit $fail
