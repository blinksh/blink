#!/bin/sh
# ensure groups handles -- sanely

# Copyright (C) 2007-2017 Free Software Foundation, Inc.

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
print_ver_ groups

# Coreutils 6.9 and earlier failed to display information on first argument
# if later argument was --.
groups none -- > out 2>&1 && fail=1
echo $? >> out
groups -- none -- > exp 2>&1 && fail=1
echo $? >> exp

compare exp out || fail=1

Exit $fail
