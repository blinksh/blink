#!/bin/sh
# Ensure that 'rm dir' (i.e., without --recursive) gives a reasonable
# diagnostic when failing.

# Copyright (C) 2005-2017 Free Software Foundation, Inc.

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


rm d 2> out && fail=1
cat <<\EOF > exp || fail=1
rm: cannot remove 'd': Is a directory
EOF

# Before coreutils-5.93 this test would fail on Solaris 9 and newer.
compare exp out || fail=1

Exit $fail
