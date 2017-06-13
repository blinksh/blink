#!/bin/sh
# For unwritable directory 'd', 'rmdir -p d d/e/f' would emit
# diagnostics but would not fail.  Fixed in 5.1.2.

# Copyright (C) 2004-2017 Free Software Foundation, Inc.

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
print_ver_ rmdir

mkdir d d/e d/e/f || framework_failure_
chmod a-w d || framework_failure_


# This rmdir command outputs two diagnostics.
# Before coreutils-5.1.2, it would mistakenly exit successfully.
# As of coreutils-5.1.2, it fails, as required.
returns_ 1 rmdir -p d d/e/f 2> /dev/null || fail=1

Exit $fail
