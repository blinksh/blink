#!/bin/sh
# tests for canonicalize-existing mode (readlink -e) on /.

# Copyright (C) 2012-2017 Free Software Foundation, Inc.

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

stat_single=$(stat -c %d:%i /) || framework_failure_
stat_double=$(stat -c %d:%i //) || framework_failure_
double_slash=//
if test x"$stat_single" = x"$stat_double"; then
  double_slash=/
fi

test -d /dev || framework_failure_

ln -s / one || framework_failure_
ln -s // two || framework_failure_
ln -s /// three || framework_failure_
ln -s /./..// one-dots || framework_failure_
ln -s //./..// two-dots || framework_failure_
ln -s ///./..// three-dots || framework_failure_
ln -s /dev one-dev || framework_failure_
ln -s //dev two-dev || framework_failure_
ln -s ///dev three-dev || framework_failure_

cat >exp <<EOF || framework_failure_
/
$double_slash
/
/
$double_slash
/
/
$double_slash
/
/
$double_slash
/
/dev
${double_slash}dev
/dev
/dev
${double_slash}dev
/dev
/dev
${double_slash}dev
/dev
EOF

{
  readlink -e / || fail=1
  readlink -e // || fail=1
  readlink -e /// || fail=1
  readlink -e /.//.. || fail=1
  readlink -e //.//.. || fail=1
  readlink -e ///.//.. || fail=1
  readlink -e one || fail=1
  readlink -e two || fail=1
  readlink -e three || fail=1
  readlink -e one-dots || fail=1
  readlink -e two-dots || fail=1
  readlink -e three-dots || fail=1
  readlink -e one-dev || fail=1
  # We know /dev exists, but cannot assume //dev exists
  readlink -f two-dev || fail=1
  readlink -e three-dev || fail=1
  readlink -e one/dev || fail=1
  readlink -f two/dev || fail=1
  readlink -e three/dev || fail=1
  readlink -e one-dots/dev || fail=1
  readlink -f two-dots/dev || fail=1
  readlink -e three-dots/dev || fail=1
} > out

compare exp out || fail=1

Exit $fail
