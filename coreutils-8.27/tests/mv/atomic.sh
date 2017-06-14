#!/bin/sh
# ensure that mv doesn't first unlink its destination in one particular case

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
require_strace_ unlink

# Before the fix, mv would unnecessarily unlink the destination symlink:
#   $ rm -rf s[12]; ln -s / s1; ln -s /tmp s2
#   $ strace -qe unlink /bin/mv -T s1 s2
#   unlink("s2") = 0
#
# With the fix, it doesn't call unlink:
#   $ rm -rf s[12]; ln -s / s1; ln -s /tmp s2
#   $ strace -qe unlink ./mv -T s1 s2
#   $

ln -s t1 s1 || framework_failure_
ln -s t2 s2 || framework_failure_


strace -qe unlink mv -T s1 s2 > out 2>&1 || fail=1
$EGREP 'unlink.*"s1"' out && fail=1

# Ensure that the source, s1, is gone.
ls -dl s1 > /dev/null 2>&1 && fail=1

# Ensure that the destination, s2, contains the link from s1.
test "$(readlink s2)" = t1 || fail=1

Exit $fail
