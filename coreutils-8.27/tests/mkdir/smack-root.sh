#!/bin/sh
# SMACK test for the mkdir,mknod, mkfifo commands.
# Derived from tests/mkdir/selinux.sh.
# Ensure that SMACK label gets set.

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
print_ver_ mkdir mkfifo mknod

require_smack_
require_root_

c=arbitrary-smack-label

for cmd in 'mkdir dir' 'mknod b p' 'mkfifo f'; do
  $cmd --context="$c" || { fail=1; continue; }
  set $cmd
  ls -dZ $2 > out || fail=1
  test "$(cut -f1 -d' ' out)" = "$c" || { cat out; fail=1; }
done

Exit $fail
