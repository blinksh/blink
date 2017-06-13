#!/bin/sh
# Ensure that mkdir -p works with arguments specified with a trailing "/.".

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
print_ver_ mkdir


mkdir -p d1/. || fail=1
test -d d1 || fail=1

mkdir -p d2/.. || fail=1
test -d d2 || fail=1

Exit $fail
