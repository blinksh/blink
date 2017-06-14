#!/bin/sh
# Try to create a symlink with backup where the destination file exists
# and the backup file name is a hard link to the destination file.

# Copyright (C) 1999-2017 Free Software Foundation, Inc.

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

# Based on a problem report from Jamie Lokier.

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ ln

touch a b || framework_failure_

ln b b~ || fail=1
ln -f --b=simple a b || fail=1

Exit $fail
