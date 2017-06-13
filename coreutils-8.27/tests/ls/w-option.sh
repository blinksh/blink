#!/bin/sh
# exercise the -w option

# Copyright (C) 2015-2017 Free Software Foundation, Inc.

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
print_ver_ ls
getlimits_

touch a b || framework_failure_
chmod a+x a || framework_failure_

# Negative values disallowed
returns_ 2 ls -w-1 || fail=1

# Verify octal parsing (especially since 0 is allowed)
returns_ 2 ls -w08 || fail=1

# Overflowed values are capped at SIZE_MAX
ls -w$SIZE_OFLOW || fail=1

# After coreutils 8.24 -w0 means no limit
# and delimiting with spaces
ls -w0 -x -T1 a b > out || fail=1
printf '%s\n' 'a  b' > exp || framework_failure_
compare exp out || fail=1

# Ensure that 0 line length doesn't cause division by zero
TERM=xterm ls -w0 -x --color=always || fail=1

# coreutils <= 8.24 could display 1 column too few
ls -w4 -x -T0 a b > out || fail=1
compare exp out || fail=1

Exit $fail
