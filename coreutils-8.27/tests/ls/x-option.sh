#!/bin/sh
# Exercise the -x option.

# Copyright (C) 2007-2017 Free Software Foundation, Inc.

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

mkdir subdir || framework_failure_
touch subdir/b || framework_failure_
touch subdir/a || framework_failure_


# Coreutils 6.8 and 6.9 would output this in the wrong order.
ls -x subdir > out || fail=1
ls -rx subdir >> out || fail=1
cat <<\EOF > exp || fail=1
a  b
b  a
EOF

compare exp out || fail=1

Exit $fail
