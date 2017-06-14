#!/bin/sh
# Test 'sort' exits early on inaccessible inputs or output

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
print_ver_ sort
skip_if_root_

SORT_FAILURE=2

# Check output is writable before starting to sort
touch input
chmod a-w input
returns_ $SORT_FAILURE timeout 10 sort -o input || fail=1

# Check all inputs are readable before starting to sort
# Also ensure the output isn't created in this case
touch output
chmod a-r output
returns_ $SORT_FAILURE timeout 10 sort -o typo - output || fail=1
test -e typo && fail=1

Exit $fail
