#!/bin/sh
# make sure 'cp -p' preserves special bits
# This works only when run as root.

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

# This test would fail due to a bug introduced in 4.0y.
# The bug was fixed in 4.0z.

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ cp
require_root_

touch a b c || framework_failure_
chmod u+sx,go= a || framework_failure_
chmod u=rwx,g=sx,o= b || framework_failure_
chmod a=r,ug+sx c || framework_failure_
chown $NON_ROOT_USERNAME . || framework_failure_
chmod u=rwx,g=rx,o=rx . || framework_failure_


cp -p a a2 || fail=1
set _ $(ls -l a); shift; p1=$1
set _ $(ls -l a2); shift; p2=$1
test $p1 = $p2 || fail=1

cp -p b b2 || fail=1
set _ $(ls -l b); shift; p1=$1
set _ $(ls -l b2); shift; p2=$1
test $p1 = $p2 || fail=1

chroot --skip-chdir --user=$NON_ROOT_USERNAME / env PATH="$PATH" cp -p c c2 \
  || fail=1
set _ $(ls -l c); shift; p1=$1
set _ $(ls -l c2); shift; p2=$1
test $p1 = $p2 && fail=1

Exit $fail
