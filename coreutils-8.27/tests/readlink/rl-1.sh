#!/bin/sh
# test for readlink mode.

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
print_ver_ readlink

mkdir subdir || framework_failure_
touch regfile || framework_failure_
ln -s regfile link1 || framework_failure_
ln -s missing link2 || framework_failure_


v=$(readlink link1) || fail=1
test "$v" = regfile || fail=1

v=$(readlink link2) || fail=1
test "$v" = missing || fail=1

v=$(returns_ 1 readlink subdir) || fail=1
test -z "$v" || fail=1

v=$(returns_ 1 readlink regfile) || fail=1
test -z "$v" || fail=1

v=$(returns_ 1 readlink missing) || fail=1
test -z "$v" || fail=1

Exit $fail
