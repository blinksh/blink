#!/bin/sh
# Make sure touch can update the times on a file that is neither
# readable nor writable.

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
print_ver_ touch

# Make sure t2 is newer than t1.
touch -d '2000-01-01 00:00' t1 || framework_failure_
touch -d '2000-01-02 00:00' t2 || framework_failure_

set x $(ls -t t1 t2)
test "$*" = "x t2 t1" || framework_failure_


chmod 0 t1
touch -d '2000-01-03 00:00' -c t1 || fail=1

set x $(ls -t t1 t2)
test "$*" = "x t1 t2" || fail=1

# Also test the combination of --no-create and -a.
touch -a --no-create t1 || fail=1

Exit $fail
