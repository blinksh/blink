#!/bin/sh
# Test "rm --dir --verbose".

# Copyright (C) 2012-2017 Free Software Foundation, Inc.

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
print_ver_ rm

mkdir a || framework_failure_
> b || framework_failure_

rm --verbose --dir a b > out || fail=1

cat <<\EOF > exp || framework_failure_
removed directory 'a'
removed 'b'
EOF

test -e a && fail=1
test -e b && fail=1

# Compare expected and actual output.
compare exp out || fail=1

Exit $fail
