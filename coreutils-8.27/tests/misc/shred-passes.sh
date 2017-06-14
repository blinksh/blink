#!/bin/sh
# Verify the operations done by shred

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
print_ver_ shred


# shred a single letter, which should result in
# 3 random passes and a single rename.
printf 1 > f || framework_failure_
echo "\
shred: f: pass 1/3 (random)...
shred: f: pass 2/3 (random)...
shred: f: pass 3/3 (random)...
shred: f: removing
shred: f: renamed to 0
shred: f: removed" > exp || framework_failure_

shred -v -u f 2>out || fail=1
compare exp out || fail=1


# Likewise but for a zero length file
# to bypass the data passes
touch f || framework_failure_
echo "\
shred: f: removing
shred: f: renamed to 0
shred: f: removed" > exp || framework_failure_

shred -v -u f 2>out || fail=1
compare exp out || fail=1


# shred data 20 times and verify the passes used.
# This would consume all random data between 5.93 and 8.24 inclusive.
dd bs=100K count=1 if=/dev/zero | tr '\0' 'U' > Us || framework_failure_
printf 1 > f || framework_failure_
echo "\
shred: f: pass 1/20 (random)...
shred: f: pass 2/20 (ffffff)...
shred: f: pass 3/20 (924924)...
shred: f: pass 4/20 (888888)...
shred: f: pass 5/20 (db6db6)...
shred: f: pass 6/20 (777777)...
shred: f: pass 7/20 (492492)...
shred: f: pass 8/20 (bbbbbb)...
shred: f: pass 9/20 (555555)...
shred: f: pass 10/20 (aaaaaa)...
shred: f: pass 11/20 (random)...
shred: f: pass 12/20 (6db6db)...
shred: f: pass 13/20 (249249)...
shred: f: pass 14/20 (999999)...
shred: f: pass 15/20 (111111)...
shred: f: pass 16/20 (000000)...
shred: f: pass 17/20 (b6db6d)...
shred: f: pass 18/20 (eeeeee)...
shred: f: pass 19/20 (333333)...
shred: f: pass 20/20 (random)...
shred: f: removing
shred: f: renamed to 0
shred: f: removed" > exp || framework_failure_

shred -v -u -n20 -s4096 --random-source=Us f 2>out || fail=1
compare exp out || fail=1


Exit $fail
