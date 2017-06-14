#!/bin/sh
# readlink from 6.9 would fail with a false-positive symlink loop error

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
print_ver_ readlink pwd
cwd=$(env pwd -P)

# To trigger this bug, we have to construct a name/situation during
# the resolution of which the code dereferences the same symlink (S)
# two different times with no actual loop.  In addition, arrange
# so that the second and fourth calls to readlink operate on S.

ln -s s p        || framework_failure_
ln -s d s        || framework_failure_
mkdir d          || framework_failure_
echo 2 > d/2     || framework_failure_
ln -s ../s/2 d/1 || framework_failure_

# With coreutils-6.9, this would fail with ELOOP.
readlink -v -e p/1 > out || fail=1
# readlink -e d/2 > exp || fail=1
echo "$cwd/d/2" > exp || fail=1
compare exp out || fail=1

# Construct a real loop and make sure readlink still detects it.
ln -sf ../s/1 d/2 || framework_failure_
readlink -v -e p/1 2> out && fail=1
readlink_msg=$(cat out)
case $readlink_msg in
  "readlink: p/1: "*) ;;
  *) fail=1;;
esac
symlink_loop_msg=${readlink_msg#"readlink: p/1: "}

# Exercise the hash table code.
ln -nsf ../s/3 d/2 || framework_failure_
ln -nsf ../p/4 d/3 || framework_failure_
ln -nsf ../p/5 d/4 || framework_failure_
ln -nsf ../p/6 d/5 || framework_failure_
ln -nsf ../p/7 d/6 || framework_failure_
ln -nsf ../p/8 d/7 || framework_failure_
echo x > d/8       || framework_failure_
readlink -v -e p/1 > out || fail=1
echo "$cwd/d/8" > exp || fail=1
compare exp out || fail=1

# A trivial loop
ln -s loop loop
readlink -v -e loop 2> out && fail=1
echo "readlink: loop: $symlink_loop_msg" > exp || framework_failure_
compare exp out || fail=1

Exit $fail
