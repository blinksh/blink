#!/bin/sh
# Ensure that touch -c no-such-file no longer fails (it did in 4.1.8).

# Copyright (C) 2002-2017 Free Software Foundation, Inc.

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
print_ver_ touch test


touch -c no-file > /dev/null 2>&1 || fail=1
touch -cm no-file > /dev/null 2>&1 || fail=1
touch -ca no-file > /dev/null 2>&1 || fail=1

# If >&- works, test "touch -c -" etc.
# >&- apparently does not work in HP-UX 11.23.
# This test is ineffective unless /dev/stdout also works.
if env test -w /dev/stdout >/dev/null &&
   env test ! -w /dev/stdout >&-; then
  touch -c - >&- 2> /dev/null || fail=1
  touch -cm - >&- 2> /dev/null || fail=1
  touch -ca - >&- 2> /dev/null || fail=1
fi

Exit $fail
