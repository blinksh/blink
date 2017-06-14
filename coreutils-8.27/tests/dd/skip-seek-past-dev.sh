#!/bin/sh
# test diagnostics are printed immediately when seeking beyond device.

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
print_ver_ dd

# need write access to local device
# (even though we don't actually write anything)
require_root_
require_local_dir_

get_device_size() {
  BLOCKDEV=blockdev
  $BLOCKDEV -V >/dev/null 2>&1 || BLOCKDEV=/sbin/blockdev
  $BLOCKDEV --getsize64 "$1"
}


# Get path to device the current dir is on.
# Note df can only get fs size, not device size.
device=$(df --output=source . | tail -n1) || framework_failure_

dev_size=$(get_device_size "$device") ||
  skip_ "failed to determine size of $device"

# Don't use shell arithmetic as older versions of dash use longs
DEV_OFLOW=$(expr $dev_size + 1) ||
  skip_ "failed to adjust device size $dev_size"

timeout 10 dd bs=1 skip=$DEV_OFLOW count=0 status=noxfer < "$device" 2> err
test "$?" = "1" || fail=1
echo "dd: 'standard input': cannot skip: Invalid argument
0+0 records in
0+0 records out" > err_ok || framework_failure_
compare err_ok err || fail=1

timeout 10 dd bs=1 seek=$DEV_OFLOW count=0 status=noxfer > "$device" 2> err
test "$?" = "1" || fail=1
echo "dd: 'standard output': cannot seek: Invalid argument
0+0 records in
0+0 records out" > err_ok || framework_failure_
compare err_ok err || fail=1

Exit $fail
