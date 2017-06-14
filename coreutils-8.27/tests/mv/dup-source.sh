#!/bin/sh
# Ensure that cp merely warns when a non-directory source file is
# listed on the command line more than once.  fileutils-4.1.1
# made this fail:  cp a a d/
# Ensure that mv fails with a similar command.

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
print_ver_ cp mv

skip_if_root_

reset_files() { rm -fr a b d; touch a; mkdir b d; }

for i in cp; do

  # cp may not fail in this case.
  reset_files
  $i a a d/ 2> out || fail=1
  reset_files
  $i ./a a d/ 2>> out || fail=1

  # Similarly for directories, but handle
  # source == dest appropriately.
  reset_files
  $i -a ./b b d/ 2>> out || fail=1
  reset_files
  returns_ 1 $i -a ./b b b/ 2>> out || fail=1

  # cp succeeds with --backup=numbered.
  reset_files
  $i --backup=numbered a a d/ 2>> out || fail=1

  # But not with plain '--backup'
  reset_files
  returns_ 1 $i --backup a a d/ 2>> out || fail=1

  cat <<EOF > exp
$i: warning: source file 'a' specified more than once
$i: warning: source file 'a' specified more than once
$i: warning: source directory 'b' specified more than once
$i: cannot copy a directory, './b', into itself, 'b/b'
$i: warning: source directory 'b' specified more than once
$i: will not overwrite just-created 'd/a' with 'a'
EOF
  compare exp out || fail=1
done

for i in mv; do
  # But mv *does* fail in this case (it has to).
  reset_files
  returns_ 1 $i a a d/ 2> out || fail=1
  returns_ 1 test -e a || fail=1
  reset_files
  returns_ 1 $i ./a a d/ 2>> out || fail=1
  returns_ 1 test -e a || fail=1

  # Similarly for directories, also handling
  # source == dest appropriately.
  reset_files
  returns_ 1 $i ./b b d/ 2>> out || fail=1
  returns_ 1 test -e b || fail=1
  reset_files
  returns_ 1 $i --verbose ./b b b/ 2>> out || fail=1
  test -d b || fail=1

  cat <<EOF > exp
$i: cannot stat 'a': No such file or directory
$i: cannot stat 'a': No such file or directory
$i: cannot stat 'b': No such file or directory
$i: cannot move './b' to a subdirectory of itself, 'b/b'
$i: warning: source directory 'b' specified more than once
EOF
  compare exp out || fail=1
done

Exit $fail
