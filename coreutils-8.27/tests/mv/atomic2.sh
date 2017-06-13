#!/bin/sh
# ensure that mv doesn't first unlink a multi-hard-linked destination

# Copyright (C) 2008-2017 Free Software Foundation, Inc.

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
require_strace_ unlink

# Before the fix, mv would unnecessarily unlink the destination symlink:
#   $ rm -f a b b2; touch a b; ln b b2; strace -e unlink /p/bin/mv a b
#   unlink("b")                             = 0
#
# With the fix, it doesn't call unlink:
#   $ rm -f a b b2; touch a b; ln b b2; strace -e unlink ./mv a b
#   $

touch a b || framework_failure_
ln b b2 || framework_failure_


strace -qe unlink mv a b > out 2>&1 || fail=1
$EGREP 'unlink.*"b"' out && fail=1

# Ensure that the source, "a", is gone.
ls -dl a > /dev/null 2>&1 && fail=1

# Ensure that the destination, "b", has link count 1.
n_links=$(stat --printf=%h b) || fail=1
test "$n_links" = 1 || fail=1

Exit $fail
