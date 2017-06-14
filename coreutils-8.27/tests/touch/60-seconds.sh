#!/bin/sh
# touch -t would mistakenly reject a time specifying "60" seconds

# Copyright (C) 2009-2017 Free Software Foundation, Inc.

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
print_ver_ touch

echo 60.000000000 > exp || framework_failure_


# Before coreutils-7.7, this would fail, complaining of
# an 'invalid date format'.  Specifying 60 seconds *is* valid.
TZ=UTC0 touch -t 197001010000.60 f || fail=1

stat --p='%.9Y\n' f > out || fail=1

compare exp out || fail=1

Exit $fail
