#!/bin/sh
# ensure that mv gives one diagnostic, not two, when failing
# due to lack of permissions

# Copyright (C) 2002-2017 Free Software Foundation, Inc.

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
skip_if_root_

mkdir -p no-write/dir || framework_failure_
chmod ug-w no-write || framework_failure_


mv no-write/dir . > out 2>&1 && fail=1
cat <<\EOF > exp
mv: cannot move 'no-write/dir' to './dir': Permission denied
EOF

compare exp out || fail=1

Exit $fail
