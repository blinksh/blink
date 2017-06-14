#!/bin/sh
# ensure that --no-target-directory (-T) works when the destination is
# an empty directory.

# Copyright (C) 2006-2017 Free Software Foundation, Inc.

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

LS_FAILURE=2

mkdir -p d/sub empty src d2/sub e2 || framework_failure_
touch f || framework_failure_

# Skip this test if there's an underlying kernel bug.
mkdir a b b/a || framework_failure_

mv a b ||
  skip_ "your kernel's rename syscall is buggy"


# This should succeed, since both src and dest are directories,
# and the dest dir is empty.
mv -fT d empty || fail=1

# Ensure that the source, d, is gone.
returns_ $LS_FAILURE ls -d d > /dev/null 2>&1 || fail=1

# Ensure that the dest dir now has a subdirectory.
test -d empty/sub || fail=1

# rename must fail, since the dest is non-empty.
returns_ 1 mv -fT src d2 2> /dev/null || fail=1

# rename must fail, since the src is not a directory.
returns_ 1 mv -fT f e2 2> /dev/null || fail=1

Exit $fail
