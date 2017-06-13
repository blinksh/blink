#!/bin/sh
# show that the following no longer makes ls infloop
# mkdir loop; cd loop; ln -s ../loop sub; ls -RL
# Also ensure ls exits with status = 2 in that case.
# Copyright (C) 2001-2017 Free Software Foundation, Inc.

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
print_ver_ ls

mkdir loop || framework_failure_
ln -s ../loop loop/sub || framework_failure_

cat <<\EOF > exp-out || framework_failure_
loop:
sub
EOF

cat <<\EOF > exp-err || framework_failure_
ls: loop/sub: not listing already-listed directory
EOF

# Ensure that ls exits with status 2 upon detecting a cycle
returns_ 2 timeout 10 ls -RL loop >out 2>err || fail=1

compare exp-err err || fail=1
compare exp-out out || fail=1

Exit $fail
