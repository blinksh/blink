#!/bin/sh
# 'test cp --update A B' where A and B are both symlinks that point
# to the same file

# Copyright (C) 2000-2017 Free Software Foundation, Inc.

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

touch file || framework_failure_
ln -s file a || framework_failure_
ln -s file b || framework_failure_
ln -s no-such-file c || framework_failure_
ln -s no-such-file d || framework_failure_

cp --update --no-dereference a b || fail=1
cp --update --no-dereference c d || fail=1

Exit $fail
