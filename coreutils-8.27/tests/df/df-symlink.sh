#!/bin/sh
# Ensure that df dereferences symlinks to disk nodes

# Copyright (C) 2013-2017 Free Software Foundation, Inc.

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

disk=$(df --out=source '.' | tail -n1) ||
  skip_ "cannot determine '.' file system"

ln -s "$disk" symlink || framework_failure_

df --out=source,target "$disk" > exp || skip_ "cannot get info for $disk"
df --out=source,target symlink > out || fail=1
compare exp out || fail=1

# Ensure we output the same values for device nodes and '.'
# This was not the case in coreutil-8.22 on systems
# where the device in the mount list was a symlink itself.
# I.e., '.' => /dev/mapper/fedora-home -> /dev/dm-2
# Restrict this test to systems with a 1:1 mapping between
# source and target.  This excludes for example BTRFS sub-volumes.
if test "$(df --output=source | grep -F "$disk" | wc -l)" = 1; then
  df --out=source,target '.' > out || fail=1
  compare exp out || fail=1
fi

test "$fail" = 1 && dump_mount_list_

Exit $fail
