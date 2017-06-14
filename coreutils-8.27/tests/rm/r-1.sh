#!/bin/sh
# Test "rm -r --verbose".

# Copyright (C) 1997-2017 Free Software Foundation, Inc.

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

mkdir a a/a || framework_failure_
> b || framework_failure_

cat <<\EOF > exp || framework_failure_
removed directory 'a/a'
removed directory 'a'
removed 'b'
EOF

rm --verbose -r a b > out || fail=1

for d in $dirs; do
  test -d $d && fail=1
done

# Compare expected and actual output.
compare exp out || fail=1

Exit $fail
