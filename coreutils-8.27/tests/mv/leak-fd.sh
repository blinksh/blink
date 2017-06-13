#!/bin/sh
# Exercise mv's file-descriptor-leak bug, reported against coreutils-5.2.1
# and fixed (properly) on 2004-10-21.

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
# limit so don't run it by default.

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ mv
skip_if_root_
cleanup_() { rm -rf "$other_partition_tmpdir"; }
. "$abs_srcdir/tests/other-fs-tmpdir"

# This test is relatively expensive, and might well evoke a
# framework-failure on systems with a smaller command-line length
expensive_

b="0 1 2 3 4 5 6 7 8 9
a b c d e f g h i j k l m n o p q r s t u v w x y z
_A _B _C _D _E _F _G _H _I _J _K _L _M _N _O _P _Q _R _S _T _U _V _W _X _Y _Z"

for i in $(echo $b); do
  echo $i
  for j in $b; do
    echo $i$j
  done
done > .dirs
mkdir $(cat .dirs) || framework_failure_
sed 's,$,/f,' .dirs | xargs touch

last_file=$(tail -n1 .dirs)/f
test -f $last_file || framework_failure_


mv * "$other_partition_tmpdir" || fail=1
test -f $last_file/f && fail=1
rm .dirs

out=$(ls -A) || fail=1
test -z "$out" || fail=1

Exit $fail
