#!/bin/sh
# ensure that a sparse file is copied efficiently, by default

# Copyright (C) 2011-2017 Free Software Foundation, Inc.

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

# Require a fiemap-enabled FS.
touch fiemap_chk
fiemap_capable_ fiemap_chk ||
  skip_ "this file system lacks FIEMAP support"

# Exclude ext[23] (or unknown fs types)
# as the emulated extent scanning can be slow
df -t ext2 -t ext3 . >/dev/null &&
  skip_ "ext[23] can have slow FIEMAP scanning"

# Create a large-but-sparse file.
timeout 10 truncate -s1T f ||
  skip_ "unable to create a 1 TiB sparse file"

# Disable this test on old BTRFS (e.g. Fedora 14)
# which reports (unwritten) extents for holes.
filefrag f || skip_ "the 'filefrag' utility is missing"
filefrag f | grep -F ': 0 extents found' > /dev/null ||
  skip_ 'this file system reports extents for holes'

# Nothing can read (much less write) that many bytes in so little time.
timeout 10 cp f f2 || fail=1

# Ensure that the sparse file copied through fiemap has the same size
# in bytes as the original.
test "$(stat --printf %s f)" = "$(stat --printf %s f2)" || fail=1

Exit $fail
