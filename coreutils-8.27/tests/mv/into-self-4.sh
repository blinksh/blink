#!/bin/sh
# confirm that 'mv symlink symlink' doesn't remove symlink
# Based on an example from David Luyer.

# Copyright (C) 2001-2017 Free Software Foundation, Inc.

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
print_ver_ mv

touch file || framework_failure_
ln -s file s || framework_failure_


# This must fail.
returns_ 1 mv s s 2> /dev/null || fail=1

# But the symlink, s, must not be removed.
# Before 4.0.36, 's' would have been removed.
test -f s || fail=1

Exit $fail
