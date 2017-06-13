#!/bin/sh
# ensure split doesn't overwrite input with output.

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
print_ver_ split

seq 10 | tee exp-1 > xaa
ln -s xaa in2
ln xaa in3

returns_ 1 split -C 6 xaa || fail=1
returns_ 1 split -C 6 in2 || fail=1
returns_ 1 split -C 6 in3 || fail=1
returns_ 1 split -C 6 - < xaa || fail=1

compare exp-1 xaa || fail=1

Exit $fail
