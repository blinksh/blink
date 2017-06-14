#!/bin/sh
# Ensure that rm -f nonexistent-file-on-read-only-fs succeeds.

# Copyright (C) 2009-2017 Free Software Foundation, Inc.

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
print_ver_ rm
require_root_

cwd=$(pwd)
cleanup_() { cd /; umount "$cwd/mnt"; }

skip=0
# Create a file system, then mount it.
dd if=/dev/zero of=blob bs=8192 count=200 > /dev/null 2>&1 \
                                             || skip=1
mkdir mnt                                    || skip=1
mkfs -t ext2 -F blob \
  || skip_ "failed to create ext2 file system"

mount -oloop blob mnt                        || skip=1
echo test > mnt/f                            || skip=1
test -s mnt/f                                || skip=1
mount -o remount,loop,ro mnt                 || skip=1

test $skip = 1 \
  && skip_ "insufficient mount/ext2 support"

# Applying rm -f to a nonexistent file on a read-only file system must succeed.
rm -f mnt/no-such > out 2>&1 || fail=1
# It must produce no diagnostic.
compare /dev/null out || fail=1

# However, trying to remove an existing file must fail.
rm -f mnt/f > out 2>&1 && fail=1
# with a diagnostic.
compare /dev/null out && fail=1

Exit $fail
