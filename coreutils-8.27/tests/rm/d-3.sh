#!/bin/sh
# Ensure that 'rm -d -i dir' (i.e., without --recursive) gives a prompt and
# then deletes the directory if it is empty

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

mkdir d || framework_failure_

echo "y" | rm -i -d --verbose d > out 2> out.err || fail=1
printf "%s" \
    "rm: remove directory 'd'? " \
    > exp.err || framework_failure_

printf "%s\n" \
    "removed directory 'd'" \
    > exp || framework_failure_

compare exp out || fail=1
compare exp.err out.err || fail=1

Exit $fail
