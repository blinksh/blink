#!/bin/sh
# cp -RL dir1 dir2' must handle the case in which each of dir1 and dir2
# contain a symlink pointing to some third directory.

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
print_ver_ cp

mkdir a b c d || framework_failure_
ln -s ../c a || framework_failure_
ln -s ../c b || framework_failure_


# Before coreutils-5.94, the following would fail with this message:
# cp: will not create hard link 'd/b/c' to directory 'd/a/c'
cp -RL a b d || fail=1
test -d a/c || fail=1
test -d b/c || fail=1

Exit $fail
