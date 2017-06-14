#!/bin/sh
# cp from 3.16 fails this test

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
print_ver_ cp

mkdir a b
msg=bar
echo $msg > a/foo
cd b
ln -s ../a/foo .
cd ..


# It should fail with a message something like this:
#   ./cp: 'a/foo' and 'b/foo' are the same file
# Fail this test if the exit status is not 1
returns_ 1 cp -d a/foo b 2>/dev/null || fail=1

test "$(cat a/foo)" = $msg || fail=1

Exit $fail
