#!/bin/sh
# exercise the -m option

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
print_ver_ ls

seq 2000 > b || framework_failure_
touch a || framework_failure_


# Before coreutils-5.1.1, the following would output a space after the comma.
ls -w2 -m a b > out || fail=1

# Before coreutils-5.1.1, the following would produce leading white space.
# All of the sed business is because the sizes are not portable.
ls -sm a b | sed 's/^[0-9]/0/;s/, [0-9][0-9]* b/, 12 b/' >> out || fail=1
cat <<\EOF > exp || fail=1
a,
b
0 a, 12 b
EOF

compare exp out || fail=1

Exit $fail
