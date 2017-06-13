#!/bin/sh
# Force mv to use the copying code.
# Consider the case where SRC and DEST are on different
# partitions and DEST is a symlink to SRC.

# Copyright (C) 1998-2017 Free Software Foundation, Inc.

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
print_ver_ mv
cleanup_() { rm -rf "$other_partition_tmpdir"; }
. "$abs_srcdir/tests/other-fs-tmpdir"

file="$other_partition_tmpdir/file"
symlink=symlink


echo whatever > $file || framework_failure_
ln -s $file $symlink || framework_failure_

# This mv command should exit nonzero.
mv $symlink $file > out 2>&1 && fail=1

# This should succeed.
mv $file $symlink || fail=1

sed \
   -e "s,mv:,XXX:," \
   -e "s,$file,YYY," \
   -e "s,$symlink,ZZZ," \
  out > out2

cat > exp <<\EOF
XXX: 'ZZZ' and 'YYY' are the same file
EOF
#'

compare exp out2 || fail=1

Exit $fail
