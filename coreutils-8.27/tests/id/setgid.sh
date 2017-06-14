#!/bin/sh
# Verify that id [-G] prints the right group when run set-GID.

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
print_ver_ id
require_root_

# Construct a different group number
gp1=$NON_ROOT_GID
gp1=$(expr $gp1 + 1) ||
  skip_ "failed to adjust GID $NON_ROOT_GID"

echo $gp1 > exp || framework_failure_

# With coreutils-8.16 and earlier, id -G would print both:
#  $gp1 $NON_ROOT_GID
chroot --skip-chdir --user=$NON_ROOT_USERNAME:+$gp1 --groups='' / \
  env PATH="$PATH" id -G > out || fail=1
compare exp out || fail=1

# With coreutils-8.22 and earlier, id would erroneously print
#  groups=$NON_ROOT_GID
chroot --skip-chdir --user=$NON_ROOT_USERNAME:+$gp1 --groups='' / \
  env PATH="$PATH" id > out || fail=1
grep -F "groups=$gp1" out || { cat out; fail=1; }

Exit $fail
