#!/bin/sh
# Test df's behavior for skipping the pseudo "rootfs" file system.

# Copyright (C) 2012-2017 Free Software Foundation, Inc.

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

# Protect against inaccessible remote mounts etc.
timeout 10 df || skip_ "df fails"

# Verify that rootfs is in mtab (and shown when the -a option is specified).
# Note this is the case when /proc/self/mountinfo is parsed
# rather than /proc/mounts.  I.e., when libmount is being used.
df -a >out || fail=1
grep '^rootfs' out || skip_ 'no rootfs in mtab'

# Ensure that rootfs is suppressed when no options is specified.
df >out || fail=1
grep '^rootfs' out && { fail=1; cat out; }

# Ensure that rootfs is yet skipped when explicitly specifying "-t rootfs".
# As df emits "no file systems processed" in this case, it would be a failure
# if df exited with status Zero.
returns_ 1 df -t rootfs >out || fail=1
grep '^rootfs' out && { fail=1; cat out; }

# Ensure that the rootfs is shown when explicitly both specifying "-t rootfs"
# and the -a option.
df -t rootfs -a >out || fail=1
grep '^rootfs' out || { fail=1; cat out; }

# Ensure that the rootfs is omitted in all_fs mode when it is explicitly
# black-listed.
df -a -x rootfs >out || fail=1
grep '^rootfs' out && { fail=1; cat out; }

test "$fail" = 1 && dump_mount_list_

Exit $fail
