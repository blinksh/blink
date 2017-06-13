#!/bin/sh
# Test for proper error and exit code of chmod on a dangling symlink.

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
print_ver_ chmod

ln -s non-existent dangle || framework_failure_


# This operation cannot succeed since the symbolic link dangles.
chmod 644 dangle 2> out && fail=1

echo "chmod: cannot operate on dangling symlink 'dangle'" > exp
compare exp out || fail=1

Exit $fail
