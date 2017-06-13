#!/bin/sh
# ensure that mv maintains a in this case: touch a; ln a b; mv a b

# Copyright (C) 2003-2017 Free Software Foundation, Inc.

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
touch a || framework_failure_
ln a b || framework_failure_

# Between coreutils-5.0 and coreutils-8.24, 'a' would be removed.
# Before coreutils-5.0.1 the issue would not have been diagnosed.
# We don't emulate the rename(a,b) with unlink(a) as that would
# introduce races with overlapping mv instances removing both links.
mv a b 2>err && fail=1
printf "mv: 'a' and 'b' are the same file\n" > exp
compare exp err || fail=1

test -r a || fail=1
test -r b || fail=1

# Make sure it works with --backup.
mv --backup=simple a b || fail=1
test -r a && fail=1
test -r b || fail=1
test -r b~ || fail=1

Exit $fail
