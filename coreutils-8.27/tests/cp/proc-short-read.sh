#!/bin/sh
# exercise cp's short-read failure when operating on >4KB files in /proc

# Copyright (C) 2009-2017 Free Software Foundation, Inc.

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

kall=/proc/kallsyms

test -r $kall || skip_ "your system lacks $kall"

# Before coreutils-7.3, cp would copy less than 4KiB of this 1MB+ file.
cp $kall 1    || fail=1
cat $kall > 2 || fail=1
compare 1 2   || fail=1

# Also check md5sum, just for good measure.
md5sum $kall > 3 || fail=1
md5sum 2     > 4 || fail=1

# Remove each file name before comparing checksums.
sed 's/ .*//' 3 > sum.proc || fail=1
sed 's/ .*//' 4 > sum.2    || fail=1
compare sum.proc sum.2 || fail=1

Exit $fail
