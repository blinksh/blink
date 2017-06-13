#!/bin/sh
# Confirm that copying a directory into itself gets a proper diagnostic.

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

# In 4.0.35 and earlier, 'mkdir dir && cp -R dir dir' would produce this:
#   cp: won't create hard link 'dir/dir/dir' to directory ''
# Now it gives this:
#   cp: can't copy a directory 'dir' into itself 'dir/dir'

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ cp

mkdir a dir || framework_failure_


# This command should exit nonzero.
cp -R dir dir 2> out && fail=1
echo 1 >> out

# This should, too.  However, with coreutils-7.1 it would infloop.
cp -rl dir dir 2>> out && fail=1
echo 2 >> out

cp -rl a dir dir 2>> out && fail=1
echo 3 >> out
cp -rl a dir dir 2>> out && fail=1
echo 4 >> out

cat > exp <<\EOF
cp: cannot copy a directory, 'dir', into itself, 'dir/dir'
1
cp: cannot copy a directory, 'dir', into itself, 'dir/dir'
2
cp: cannot copy a directory, 'dir', into itself, 'dir/dir'
3
cp: cannot copy a directory, 'dir', into itself, 'dir/dir'
4
EOF
#'

compare exp out || fail=1

Exit $fail
