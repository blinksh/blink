#!/bin/sh
# Test "ln --target-dir" with one file.

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

# Before coreutils-4.5.3, --target-dir didn't work with one file.
# It would create the desired link, but would fail with a diagnosis like this:
# ln: 'd/.': cannot overwrite directory
# Based on a test case from Dmitry V. Levin.

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ ln

mkdir d || framework_failure_
ln -s --target-dir=d ../f || fail=1

Exit $fail
