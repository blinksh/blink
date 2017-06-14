#!/bin/sh
# Test cp backup.

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

suffix=.b
file=F
file_backup="$file$suffix"

echo test > $file || fail=1

# Specify both version control and suffix so the environment variables
# (possibly set by the user running these tests) aren't used.
cp --force --backup=simple --suffix=$suffix $file $file || fail=1
cp -T --force --backup=simple --suffix=$suffix $file $file || fail=1

test -f $file || fail=1
test -f $file_backup || fail=1
compare $file $file_backup > /dev/null || fail=1

Exit $fail
