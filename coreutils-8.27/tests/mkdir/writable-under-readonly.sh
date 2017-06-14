#!/bin/sh
# FIXME: convert this to a root-only test.

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

# Test for the 2005-10-13 patch to lib/mkdir-p.c that fixed this sort
# of bug in mkdir:
#
#   "mkdir -p /a/b/c" no longer fails merely because a leading prefix
#   directory (e.g., /a or /a/b) exists on a read-only file system.
#
# Demonstrate the problem, as root:

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ mkdir
require_root_

# FIXME: for now, skip it unconditionally
skip_ temporarily disabled

# FIXME: define cleanup_ to do the umount

# FIXME: use mktemp
cd /tmp                                    \
  && dd if=/dev/zero of=1 bs=8192 count=50 \
  && dd if=/dev/zero of=2 bs=8192 count=50 \
  && mkdir -p mnt-ro && mkfs -t ext2 1 && mkfs -t ext2 2 \
  && mount -o loop=/dev/loop3 1 mnt-ro    \
  && mkdir -p mnt-ro/rw                    \
  && mount -o remount,ro mnt-ro           \
  && mount -o loop=/dev/loop4 2 mnt-ro/rw

mkdir -p mnt-ro/rw/sub || fail=1

# To clean up
umount /tmp/2
umount /tmp/1

Exit $fail
