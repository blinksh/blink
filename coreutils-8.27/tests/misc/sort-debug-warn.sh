#!/bin/sh
# Test warnings for sort options

# Copyright (C) 2010-2017 Free Software Foundation, Inc.

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
print_ver_ sort

cat <<\EOF > exp
1
sort: using simple byte comparison
sort: key 1 has zero width and will be ignored
2
sort: using simple byte comparison
sort: key 1 has zero width and will be ignored
3
sort: using simple byte comparison
sort: key 1 is numeric and spans multiple fields
4
sort: using simple byte comparison
sort: options '-bghMRrV' are ignored
5
sort: using simple byte comparison
sort: options '-bghMRV' are ignored
sort: option '-r' only applies to last-resort comparison
6
sort: using simple byte comparison
sort: option '-r' only applies to last-resort comparison
7
sort: using simple byte comparison
sort: leading blanks are significant in key 2; consider also specifying 'b'
sort: options '-bg' are ignored
8
sort: using simple byte comparison
9
sort: using simple byte comparison
sort: option '-b' is ignored
10
sort: using simple byte comparison
11
sort: using simple byte comparison
sort: leading blanks are significant in key 1; consider also specifying 'b'
12
sort: using simple byte comparison
sort: leading blanks are significant in key 1; consider also specifying 'b'
13
sort: using simple byte comparison
sort: leading blanks are significant in key 1; consider also specifying 'b'
sort: option '-d' is ignored
14
sort: using simple byte comparison
sort: leading blanks are significant in key 1; consider also specifying 'b'
sort: option '-i' is ignored
15
sort: using simple byte comparison
16
sort: using simple byte comparison
17
sort: using simple byte comparison
18
sort: failed to set locale; using simple byte comparison
EOF

echo 1 >> out
sort -s -k2,1 --debug /dev/null 2>>out
echo 2 >> out
sort -s -k2,1n --debug /dev/null 2>>out
echo 3 >> out
sort -s -k1,2n --debug /dev/null 2>>out
echo 4 >> out
sort -s -rRVMhgb -k1,1n --debug /dev/null 2>>out
echo 5 >> out
sort -rRVMhgb -k1,1n --debug /dev/null 2>>out
echo 6 >> out
sort -r -k1,1n --debug /dev/null 2>>out
echo 7 >> out
sort -gbr -k1,1n -k1,1r --debug /dev/null 2>>out
echo 8 >> out
sort -b -k1b,1bn --debug /dev/null 2>>out # no warning
echo 9 >> out
sort -b -k1,1bn --debug /dev/null 2>>out
echo 10 >> out
sort -b -k1,1bn -k2b,2 --debug /dev/null 2>>out # no warning
echo 11 >> out
sort -r -k1,1r --debug /dev/null 2>>out # no warning for redundant options
echo 12 >> out
sort -i -k1,1i --debug /dev/null 2>>out # no warning
echo 13 >> out
sort -d -k1,1b --debug /dev/null 2>>out
echo 14 >> out
sort -i -k1,1d --debug /dev/null 2>>out
echo 15 >> out
sort -r --debug /dev/null 2>>out #no warning
echo 16 >> out
sort -rM --debug /dev/null 2>>out #no warning
echo 17 >> out
sort -rM -k1,1 --debug /dev/null 2>>out #no warning
echo 18 >> out
LC_ALL=missing sort --debug /dev/null 2>>out

compare exp out || fail=1

cat <<\EOF > exp
sort: using simple byte comparison
sort: key 1 is numeric and spans multiple fields
sort: obsolescent key '+2 -1' used; consider '-k 3,1' instead
sort: key 2 has zero width and will be ignored
sort: option '-b' is ignored
sort: option '-r' only applies to last-resort comparison
EOF

sort --debug -rb -k2n +2.2 -1b /dev/null 2>out

compare exp out || fail=1

Exit $fail
