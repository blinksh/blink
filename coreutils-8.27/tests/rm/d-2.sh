#!/bin/sh
# Ensure that 'rm -d dir' (i.e., without --recursive) gives a reasonable
# diagnostic when failing.

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
> d/a || framework_failure_

rm -d d 2> out && fail=1

# Accept any of these: EEXIST, ENOTEMPTY
sed 's/: File exists/: Directory not empty/' out > out2

printf "%s\n" \
    "rm: cannot remove 'd': Directory not empty" \
    > exp || framework_failure_

compare exp out2 || fail=1

Exit $fail
