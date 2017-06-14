#!/bin/sh
# Ensure that tac processes all command line arguments, even
# when it encounters an error with say the first one.
# With coreutils-5.2.1 and earlier, this test would fail.

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
print_ver_ tac

# See if the envvar is defined.
if test x = "x$FULL_PARTITION_TMPDIR"; then
  skip_ "FULL_PARTITION_TMPDIR not defined"
fi

if ! test -d "$FULL_PARTITION_TMPDIR"; then
  echo "$0: $FULL_PARTITION_TMPDIR:" \
    "\$FULL_PARTITION_TMPDIR does not specify a directory" 1>&2
  Exit 1
fi

fp_tmp="$FULL_PARTITION_TMPDIR/tac-cont-$$"
cleanup_()
{
  # Terminate any background process
  # and remove tmp dir
  rm -f "$fp_tmp"
  kill $pid 2>/dev/null && wait $pid
}

# Make sure we can create an empty file there (i.e., no shortage of inodes).
if ! touch $fp_tmp; then
  echo "$0: $fp_tmp: cannot create empty file" 1>&2
  Exit 1
fi

# Make sure that we fail when trying to create a file large enough
# to consume a non-inode block.
if seq 1000 > $fp_tmp 2>/dev/null; then
  echo "$0: $FULL_PARTITION_TMPDIR: not a full partition" 1>&2
  Exit 1
fi

seq 5 > in


# Give tac a fifo command line argument.
# This makes it try to create a temporary file in $TMPDIR.
mkfifo_or_skip_ fifo
seq 1000 > fifo & pid=$!
TMPDIR=$FULL_PARTITION_TMPDIR tac fifo in >out 2>err && fail=1

cat <<\EOF > exp || fail=1
5
4
3
2
1
EOF

compare exp out || fail=1

Exit $fail
