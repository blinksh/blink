#!/bin/sh
# Make sure name is used as secondary key when sorting on mtime or ctime.

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
print_ver_ ls touch

date=1998-01-15

touch -d "$date" c || framework_failure_
touch -d "$date" a || framework_failure_
touch -d "$date" b || framework_failure_


ls -1t a b c > out || fail=1
cat <<EOF > exp
a
b
c
EOF
compare exp out || fail=1

rm -rf out exp
ls -1rt a b c > out || fail=1
cat <<EOF > exp
c
b
a
EOF
compare exp out || fail=1

Exit $fail
