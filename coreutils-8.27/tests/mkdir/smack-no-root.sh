#!/bin/sh
# SMACK test for the mkdir,mknod, mkfifo commands.
# Derived from tests/mkdir/selinux.sh.
# Ensure that an unsettable SMACK label doesn't cause a segfault.

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

c=arbitrary-smack-label
msg="failed to set default file creation context to '$c':"

for cmd in 'mkdir dir' 'mknod b p' 'mkfifo f'; do
  $cmd --context="$c" 2> out && fail=1
  set $cmd
  echo "$1: $msg" > exp || fail=1

  sed -e 's/ Operation not permitted$//' out > k || fail=1
  mv k out || fail=1
  compare exp out || fail=1
done

Exit $fail
