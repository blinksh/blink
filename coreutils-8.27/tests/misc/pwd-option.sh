#!/bin/sh
# Ensure that pwd options work.

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
print_ver_ pwd

mkdir -p a/b || framework_failure_
ln -s a/b c || framework_failure_
base=$(env -- pwd -P)

# Remove any logical paths from $PWD.
cd "$base" || framework_failure_
test "x$PWD" = "x$base" || framework_failure_

# Enter a logical directory.
cd c || framework_failure_
test "x$PWD" = "x$base/c" || skip_ "cd does not properly update \$PWD"

env -- pwd -L > out || fail=1
printf %s\\n "$base/c" > exp || fail=1

env -- pwd --logical -P >> out || fail=1
printf %s\\n "$base/a/b" >> exp || fail=1

env -- pwd --physical >> out || fail=1
printf %s\\n "$base/a/b" >> exp || fail=1

# By default, we use -P unless POSIXLY_CORRECT.
env -- pwd >> out || fail=1
printf %s\\n "$base/a/b" >> exp || fail=1

env -- POSIXLY_CORRECT=1 pwd >> out || fail=1
printf %s\\n "$base/c" >> exp || fail=1

# Make sure we reject bogus values, and silently fall back to -P.
env -- PWD="$PWD/." pwd -L >> out || fail=1
printf %s\\n "$base/a/b" >> exp || fail=1

env -- PWD=bogus pwd -L >> out || fail=1
printf %s\\n "$base/a/b" >> exp || fail=1

env -- PWD="$base/a/../c" pwd -L >> out || fail=1
printf %s\\n "$base/a/b" >> exp || fail=1

compare exp out || fail=1

Exit $fail
