#!/bin/sh
# rm (coreutils-4.5.4) could be tricked into mistakenly reporting a cycle.

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
print_ver_ rm
skip_if_root_

mkdir -p a/b
touch a/b/file
chmod ug-w a/b


rm -rf a a 2>&1 | sed 's/:[^:]*$//' > out || fail=1
cat <<\EOF > exp
rm: cannot remove 'a/b/file'
rm: cannot remove 'a/b/file'
EOF

compare exp out || fail=1

Exit $fail
