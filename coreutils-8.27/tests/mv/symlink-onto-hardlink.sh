#!/bin/sh
# Ensure that mv works with a few symlink-onto-hard-link cases.

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
print_ver_ mv

touch f || framework_failure_
ln f h || framework_failure_
ln -s f s || framework_failure_

# Given two links f and h to some important content, and a symlink s to f,
# "mv s f" must fail because it might then be hard to find the link, h.
# "mv s l" may succeed because then, s (now "l") still points to f.
# Of course, if the symlink were being moved into a different destination
# directory, things would be very different, and, I suspect, implausible.

echo "mv: 's' and 'f' are the same file" > exp || framework_failure_
mv s f > out 2> err && fail=1
compare /dev/null out || fail=1
compare exp err || fail=1

mv s l > out 2> err || fail=1
compare /dev/null out || fail=1
compare /dev/null err || fail=1

Exit $fail
