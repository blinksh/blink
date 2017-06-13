#!/bin/sh
# Ensure that cp copies contents of non-empty "regular" file with st_size==0

# Copyright (C) 2007-2017 Free Software Foundation, Inc.

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

touch empty || framework_failure_

f=/proc/cpuinfo
test -r $f || f=empty

cat $f > out || fail=1

# With coreutils-6.9, this would create a zero-length "exp" file.
# Skip this test on architectures like aarch64 where the inode
# number of the file changed during the cp run.
cp $f exp 2>err \
  || { fail=1;
       grep 'replaced while being copied' err \
         && skip_ "File $f is being replaced while being copied"; }

# Don't simply compare contents; they might differ,
# e.g., if CPU freq changes between cat and cp invocations.
# Instead, simply compare whether they're both nonempty.
test -s out \
  && { rm -f out; echo nonempty > out; }
test -s exp \
  && { rm -f exp; echo nonempty > exp; }

compare exp out || fail=1

Exit $fail
