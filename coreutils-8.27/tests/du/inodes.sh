#!/bin/sh
# exercise du's --inodes option

# Copyright (C) 2010-2017 Free Software Foundation, Inc.

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

# An empty directory uses only 1 inode.
mkdir d || framework_failure_
printf '1\td\n' > exp || framework_failure_

du --inodes d > out 2>err || fail=1
compare exp out || fail=1
compare /dev/null err || fail=1

# Add a regular file: 2 inodes used.
touch d/f || framework_failure_
printf '2\td\n' > exp || framework_failure_

du --inodes d > out 2>err || fail=1
compare exp out || fail=1
compare /dev/null err || fail=1

# Add a hardlink to the file: still only 2 inodes used.
ln -v d/f d/h || framework_failure_
du --inodes d > out 2>err || fail=1
compare exp out || fail=1
compare /dev/null err || fail=1

# Now count also hardlinks (-l,--count-links): 3 inodes.
printf '3\td\n' > exp || framework_failure_
du --inodes -l d > out 2>err || fail=1
compare exp out || fail=1
compare /dev/null err || fail=1

# Create a directory and summarize: 3 inodes.
mkdir d/d || framework_failure_
du --inodes -s d > out 2>err || fail=1
compare exp out || fail=1
compare /dev/null err || fail=1

# Count inodes separated: 1-2.
printf '1\td/d\n2\td\n' > exp || framework_failure_
du --inodes -S d > out 2>err || fail=1
compare exp out || fail=1
compare /dev/null err || fail=1

# Count inodes cumulative (default): 1-3.
printf '1\td/d\n3\td\n' > exp || framework_failure_
du --inodes d > out 2>err || fail=1
compare exp out || fail=1
compare /dev/null err || fail=1

# Count all items: 1-1-3.
# Sort output because the directory entry order is not defined.
# Also replace the hardlink with the original file name because
# the system may either return 'd/f' or 'd/h' first, and du(1)
# will ignore the other one.
printf '1\td/d\n1\td/f\n3\td\n' | sort > exp || framework_failure_
du --inodes -a d > out.tmp 2>err || fail=1
sed 's/h$/f/' out.tmp | sort >out || framework_failure_
compare exp out || fail=1
compare /dev/null err || fail=1

# Count all items and hardlinks again: 1-1-1-4
# Sort output because the directory entry order is not defined.
printf '1\td/d\n1\td/h\n1\td/f\n4\td\n' | sort > exp || framework_failure_
du --inodes -al d > out.tmp 2>err || fail=1
sort <out.tmp >out || framework_failure_
compare exp out || fail=1
compare /dev/null err || fail=1

# Run with total (-c) line: 1-3-3
printf '1\td/d\n3\td\n3\ttotal\n' > exp || framework_failure_
du --inodes -c d > out 2>err || fail=1
compare exp out || fail=1
compare /dev/null err || fail=1

# Create another file in the subdirectory: 2-4
touch d/d/f || framework_failure_
printf '2\td/d\n4\td\n' > exp || framework_failure_
du --inodes d > out 2>err || fail=1
compare exp out || fail=1
compare /dev/null err || fail=1

# Ensure human output (-h, --si) works.
rm -rf d || framework_failure_
mkdir d || framework_failure_
seq --format="d/file%g" 1023 | xargs touch || framework_failure_
printf '1.0K\td\n' > exp || framework_failure_
du --inodes -h d > out 2>err || fail=1
compare exp out || fail=1
compare /dev/null err || fail=1

printf '1.1k\td\n' > exp || framework_failure_
du --inodes --si d > out 2>err || fail=1
compare exp out || fail=1
compare /dev/null err || fail=1

# Verify --inodes ignores -B.
printf '1024\td\n' > exp || framework_failure_
du --inodes -B10 d > out 2>err || fail=1
compare exp out || fail=1
compare /dev/null err || fail=1

# Verify --inodes works with --threshold.
printf '1024\td\n' > exp || framework_failure_
du --inodes --threshold=1000 d > out 2>err || fail=1
compare exp out || fail=1
compare /dev/null err || fail=1

du --inodes --threshold=-1000 d > out 2>err || fail=1
compare /dev/null out || fail=1
compare /dev/null err || fail=1

# Verify --inodes raises a warning for --apparent-size and -b.
du --inodes -b d > out 2>err || fail=1
grep ' ineffective ' err >/dev/null || { fail=1; cat out err; }

du --inodes --apparent-size d > out 2>err || fail=1
grep ' ineffective ' err >/dev/null || { fail=1; cat out err; }

# Ensure that --inodes is mentioned in the usage.
du --help > out || fail=1
grep ' --inodes ' out >/dev/null || { fail=1; cat out; }
Exit $fail
