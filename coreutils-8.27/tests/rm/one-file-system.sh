#!/bin/sh
# Demonstrate rm's new --one-file-system option.

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
print_ver_ rm
require_root_

cleanup_()
{
  # When you take the undesirable shortcut of making /etc/mtab a link
  # to /proc/mounts, unmounting "$other_partition_tmpdir" would fail.
  # So, here we unmount a/b instead.
  umount a/b
  rm -rf "$other_partition_tmpdir"
}
. "$abs_srcdir/tests/other-fs-tmpdir"

t=$other_partition_tmpdir
mkdir -p a/b $t/y
mount --bind $t a/b \
  || skip_ "This test requires mount with a working --bind option."

cat <<\EOF > exp || framework_failure_
rm: skipping 'a/b', since it's on a different device
EOF


rm --one-file-system -rf a 2> out && fail=1
test -d $t/y || fail=1

compare exp out || fail=1

Exit $fail
