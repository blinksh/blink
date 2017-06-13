#!/bin/sh
# Test for bugs in du's --one-file-system (-x) option.

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
cleanup_() { rm -rf "$other_partition_tmpdir"; }
. "$abs_srcdir/tests/other-fs-tmpdir"

mkdir -p b/c y/z d "$other_partition_tmpdir/x" || framework_failure_
ln -s "$other_partition_tmpdir/x" d || framework_failure_

# Due to a used-uninitialized variable, the "du -x" from coreutils-6.6
# would not traverse into second and subsequent directories listed
# on the command line.
du -ax b y > t || fail=1
sed 's/^[0-9][0-9]*	//' t > out
cat <<\EOF > exp || fail=1
b/c
b
y/z
y
EOF

compare exp out || fail=1

# "du -xL" reported a zero count for a file in a different file system,
# instead of ignoring it.
du -xL d > u || fail=1
sed 's/^[0-9][0-9]*	//' u > out1
echo d > exp1 || fail=1
compare exp1 out1 || fail=1

# With coreutils-8.15, "du -xs FILE" would print no output.
touch f
for opt in -x -xs; do
  du $opt f > u || fail=1
  sed 's/^[0-9][0-9]*	//' u > out2
  echo f > exp2 || fail=1
  compare exp2 out2 || fail=1
done

Exit $fail
