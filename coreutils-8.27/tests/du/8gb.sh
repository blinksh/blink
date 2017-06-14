#!/bin/sh
# Ensure that du does not rely on narrow types like size_t for
# file sizes or sums.

# Copyright (C) 2003-2017 Free Software Foundation, Inc.

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
require_sparse_support_

dd bs=1 seek=8G of=big < /dev/null 2> /dev/null
if test $? != 0; then
  skip_ 'cannot create a file large enough for this test; possibly
because file offsets are only 32 bits on this file system'
fi

# FIXME: this should be a test of dd.
# On some systems (at least linux-2.4.18 + NFS to disks on a Solaris system)
# the 'dd' command above mistakenly creates a file of length '0', yet
# doesn't fail.  The root of that failure is that the ftruncate call
# returns zero but doesn't do its job.  Detect this failure.
set x $(ls -gG big)
size=$4
if test "$size" = 0; then
  skip_ "cannot create a file large enough for this test
possibly because this system's NFS support is buggy
Consider rerunning this test on a different file system."
fi


# This would print '0	big' with coreutils-4.5.8.
du -ab big > out || fail=1

cat <<\EOF > exp
8589934592	big
EOF

compare exp out || fail=1

Exit $fail
