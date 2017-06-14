#!/bin/sh
# Demonstrate a bug in 'tail -cN' when operating on files of size 4G and larger
# Fixed in coreutils-4.5.2.

# Copyright (C) 2002-2017 Free Software Foundation, Inc.

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
print_ver_ tail
expensive_

# Create a file of size exactly 4GB (2^32) with 8 bytes
# at the beginning and another set of 8 bytes at the end.
# The rest will be NUL bytes.  On most modern systems, the following
# creates a file that takes up only a few KB.  Here, du -sh says 16K.
echo abcdefgh | tr -d '\n' > big || framework_failure_
echo 87654321 | tr -d '\n' > tmp || framework_failure_
# Seek 4GB - 8
dd bs=1 seek=4294967288 if=tmp of=big 2> err || dd_failed=1
if test "$dd_failed" = 1; then
  cat err 1>&2
  skip_ \
'cannot create a file large enough for this test,
possibly because this system does not support large files;
Consider rerunning this test on a different file system.'
fi


tail -c1 big > out || fail=1
# Append a newline.
echo >> out
cat <<\EOF > exp
1
EOF

compare exp out || fail=1

Exit $fail
