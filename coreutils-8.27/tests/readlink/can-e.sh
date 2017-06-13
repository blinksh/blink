#!/bin/sh
# tests for canonicalize-existing mode (readlink -e).

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
print_ver_ readlink pwd

pwd=$(pwd)
my_pwd=$(env pwd -P)
tmp=d

mkdir $tmp || framework_failure_
cd $tmp || framework_failure_

mkdir subdir removed || framework_failure_
touch regfile || framework_failure_

ln -s regfile link1 || framework_failure_
ln -s subdir link2 || framework_failure_
ln -s missing link3 || framework_failure_
ln -s subdir/missing link4 || framework_failure_

cd "$pwd/$tmp/removed" || framework_failure_

# Skip this test if the system doesn't let you remove the working directory.
if rmdir ../removed 2>/dev/null; then
  v=$(returns_ 1 readlink -e .) || fail=1
  test -z "$v" || fail=1
fi

cd "$pwd/$tmp" || fail=1

for p in "" "$pwd/$tmp/"; do

  v=$(readlink -e "${p}regfile") || fail=1
  test "$v" = "$my_pwd/$tmp/regfile" || fail=1

  v=$(returns_ 1 readlink -e "${p}./regfile/") || fail=1
  test -z "$v" || fail=1

  v=$(readlink -e "${p}subdir") || fail=1
  test "$v" = "$my_pwd/$tmp/subdir" || fail=1

  v=$(readlink -e "${p}./subdir/") || fail=1
  test "$v" = "$my_pwd/$tmp/subdir" || fail=1

  v=$(returns_ 1 readlink -e "${p}missing") || fail=1
  test -z "$v" || fail=1

  v=$(returns_ 1 readlink -e "${p}./missing/") || fail=1
  test -z "$v" || fail=1

  v=$(readlink -e "${p}link1") || fail=1
  test "$v" = "$my_pwd/$tmp/regfile" || fail=1

  v=$(returns_ 1 readlink -e "${p}./link1/") || fail=1
  test -z "$v" || fail=1

  v=$(returns_ 1 readlink -e "${p}link1/more") || fail=1
  test -z "$v" || fail=1

  v=$(readlink -e "${p}link2") || fail=1
  test "$v" = "$my_pwd/$tmp/subdir" || fail=1

  v=$(readlink -e "${p}./link2/") || fail=1
  test "$v" = "$my_pwd/$tmp/subdir" || fail=1

  v=$(returns_ 1 readlink -e "${p}link2/more") || fail=1
  test -z "$v" || fail=1

  v=$(returns_ 1 readlink -e "${p}link3") || fail=1
  test -z "$v" || fail=1

  v=$(returns_ 1 readlink -e "${p}./link3/") || fail=1
  test -z "$v" || fail=1

  v=$(returns_ 1 readlink -e "${p}link3/more") || fail=1
  test -z "$v" || fail=1

  v=$(returns_ 1 readlink -e "${p}link4") || fail=1
  test -z "$v" || fail=1

  v=$(returns_ 1 readlink -e "${p}./link4/") || fail=1
  test -z "$v" || fail=1

  v=$(returns_ 1 readlink -e "${p}link4/more") || fail=1
  test -z "$v" || fail=1
done

Exit $fail
