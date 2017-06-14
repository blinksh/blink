#!/bin/sh
# Since the rewrite for fileutils-4.1.9, 'rm -i DIR' would mistakenly
# recurse into directory DIR.  rm -i (without -r) must fail in that case.
# Fixed in coreutils-4.5.2.

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
print_ver_ rm

mkdir dir || framework_failure_
echo y > y || framework_failure_


# This must fail.
returns_ 1 rm -i dir < y > /dev/null 2>&1 || fail=1

# The directory must remain.
test -d dir || fail=1

Exit $fail
