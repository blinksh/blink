#!/bin/sh
# test cp's -H and -L options

# Copyright (C) 2000-2017 Free Software Foundation, Inc.

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

mkdir src-dir dest-dir || framework_failure_
echo f > f || framework_failure_
ln -s f slink || framework_failure_
ln -s no-such-file src-dir/slink || framework_failure_


cp -H -R slink src-dir dest-dir || fail=1
test -d src-dir || fail=1
test -d dest-dir/src-dir || fail=1

# Expect this to succeed since this slink is not a symlink
cat dest-dir/slink > /dev/null 2>&1 || fail=1

# Expect this to fail since *this* slink is a dangling symlink.
returns_ 1 cat dest-dir/src-dir/slink >/dev/null 2>&1 || fail=1

# FIXME: test -L, too.

Exit $fail
