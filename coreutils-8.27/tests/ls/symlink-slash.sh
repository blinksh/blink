#!/bin/sh
# Do dereference a symlink arg if its name is written with a trailing slash.

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

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ ls

mkdir dir || framework_failure_
ln -s dir symlink || framework_failure_

set $(ls -l symlink/)

# Prior to fileutils-4.0k, the following would have output '... symlink -> dir'.
test "$*" = 'total 0' && : || fail=1

Exit $fail
