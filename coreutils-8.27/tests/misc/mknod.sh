#!/bin/sh
# Ensure that mknod, mkfifo, mkdir -m MODE work with a restrictive umask

# Copyright (C) 2004-2017 Free Software Foundation, Inc.

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
print_ver_ mknod

# Ensure fifos are supported
mkfifo_or_skip_ fifo

umask 777

mknod  -m 734 f1 p || fail=1
mode=$(ls -dgo f1|cut -b-10)
test $mode = prwx-wxr-- || fail=1

mkfifo -m 734 f2   || fail=1
mode=$(ls -dgo f2|cut -b-10)
test $mode = prwx-wxr-- || fail=1

mkdir -m 734 f3   || fail=1
mode=$(ls -dgo f3|cut -b-10)
test $mode = drwx-wxr-- || test $mode = drwx-wsr-- || fail=1

Exit $fail
