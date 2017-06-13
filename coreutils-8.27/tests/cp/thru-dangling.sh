#!/bin/sh
# Ensure that cp works as documented, when the destination is a dangling symlink

# Copyright (C) 2007-2017 Free Software Foundation, Inc.

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
print_ver_ cp

ln -s no-such dangle || framework_failure_
echo hi > f || framework_failure_
echo hi > exp || framework_failure_
echo "cp: not writing through dangling symlink 'dangle'" \
    > exp-err || framework_failure_


# Starting with 6.9.90, this usage fails, by default:
cp f dangle > err 2>&1 && fail=1

compare exp-err err || fail=1
test -f no-such && fail=1

# But you can set POSIXLY_CORRECT to get the historical behavior.
env POSIXLY_CORRECT=1 cp f dangle > out 2>&1 || fail=1
cat no-such >> out || fail=1

compare exp out || fail=1

Exit $fail
