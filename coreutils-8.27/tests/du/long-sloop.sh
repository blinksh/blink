#!/bin/sh
# Use du to exercise a corner of fts's FTS_LOGICAL code.
# Show that du fails with ELOOP (Too many levels of symbolic links)
# when it encounters that condition.

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
print_ver_ du

# Create lots of directories, each containing a single symlink
# pointing at the next directory in the list.

# This number should be larger than the number of symlinks allowed in
# file name resolution, but not too large as a number of entries
# in a single directory.
n=400

dir_list=$(seq $n)
mkdir $dir_list || framework_failure_
file=1
i_minus_1=0
for i in $dir_list $(expr $n + 1); do
  case $i_minus_1 in
  0) ;;
  *)
    ln -s ../$i $i_minus_1/s || framework_failure_
    file=$file/s;;
  esac
  i_minus_1=$i
done
echo foo > $i

# If a system can handle this many symlinks in a file name,
# just skip this test.

# The following also serves to record in 'err' the string
# corresponding to strerror (ELOOP).  This is necessary because while
# Linux/libc gives 'Too many levels of symbolic links', Solaris
# renders it as "Number of symbolic links encountered during path
# name traversal exceeds MAXSYMLINKS".

cat $file > /dev/null 2> err &&
    skip_ 'Your system appears to be able to handle more than $n symlinks
in file name resolution'
too_many=$(sed 's/.*: //' err)


# With coreutils-5.93 there was no failure.
# With coreutils-5.94 we get the desired diagnostic:
# du: cannot access '1/s/s/s/.../s': Too many levels of symbolic links
du -L 1 > /dev/null 2> out1 && fail=1
sed "s, .1/s/s/s/[/s]*',," out1 > out || fail=1

echo "du: cannot access: $too_many" > exp || fail=1

compare exp out || fail=1

Exit $fail
