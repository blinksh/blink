#!/bin/sh
# Ensure that du works properly for an argument that refers to a
# symbolic link, and that is specified with a trailing slash.

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

# Before coreutils-4.5.3, it would remove a single trailing slash.

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ du

mkdir -p dir/1/2 || framework_failure_
ln -s dir slink || framework_failure_


du slink/ | sed 's/^[0-9][0-9]*	//' > out
echo === >> out

# Ensure that with -L we get the same results (modulo the trailing slash
# on the third line) even without the trailing slash on the command line.
du -L slink | sed 's/^[0-9][0-9]*	//' >> out
cat <<\EOF > exp
slink/1/2
slink/1
slink/
===
slink/1/2
slink/1
slink
EOF

compare exp out || fail=1

Exit $fail
