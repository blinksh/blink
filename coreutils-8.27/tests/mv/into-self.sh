#!/bin/sh
# Demonstrate how mv fails when it tries to move a directory into itself.

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

dir=toself-dir
file=toself-file

rm -rf $dir $file || framework_failure_
mkdir -p $dir/a/b || framework_failure_
touch $file || framework_failure_


# This mv command should fail.
mv $dir $file $dir > out 2>&1 && fail=1

sed \
   -e "s,mv:,XXX:," \
   -e "s,$dir,SRC," \
   -e "s,$dir/$dir,DEST," \
  out > out2

cat > exp <<\EOF
XXX: cannot move 'SRC' to a subdirectory of itself, 'DEST'
EOF

compare exp out2 || fail=1

# Make sure the file is gone.
test -f $file && fail=1
# Make sure the directory is *not* moved.
test -d $dir || fail=1
test -d $dir/$dir && fail=1
# Make sure the file has been moved to the right place.
test -f $dir/$file || fail=1

Exit $fail
