#!/bin/sh
# make sure ls and 'ls -R' do the right thing when invoked with no arguments.

# Copyright (C) 2001-2017 Free Software Foundation, Inc.

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
print_ver_ ls

mkdir -p dir/subdir || framework_failure_
touch dir/subdir/file2 || framework_failure_
ln -s f symlink || framework_failure_

cat > exp <<\EOF || framework_failure_
dir
exp
out
symlink
EOF


ls -1 > out || fail=1

compare exp out || fail=1

cat > exp <<\EOF
.:
dir
exp
out
symlink

./dir:
subdir

./dir/subdir:
file2
EOF

ls -R1 > out || fail=1

compare exp out || fail=1

Exit $fail
