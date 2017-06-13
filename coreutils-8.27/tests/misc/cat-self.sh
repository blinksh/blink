#!/bin/sh
# Check that cat operates correctly when the input is the same as the output.

# Copyright 2014-2017 Free Software Foundation, Inc.

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
print_ver_ cat

echo x >out || framework_failure_
echo x >out1 || framework_failure_
returns_ 1 cat out >>out || fail=1
compare out out1 || fail=1

# This example is taken from the POSIX spec for 'cat'.
echo x >doc || framework_failure_
echo y >doc.end || framework_failure_
cat doc doc.end >doc || fail=1
compare doc doc.end || fail=1

Exit $fail
