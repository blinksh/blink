#!/bin/sh
# test -C, --lines-bytes

# Copyright (C) 2013-2017 Free Software Foundation, Inc.

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
print_ver_ split

vm=$(get_min_ulimit_v_ split -C 'K' /dev/null) \
  || skip_ "this shell lacks ulimit support"

# Ensure memory is not allocated up front
(ulimit -v $vm && split -C 'G' /dev/null) || fail=1


# Ensure correct operation with various split and buffer size combinations

lines=\
1~2222~3~4

printf '%s' "$lines" | tr '~' '\n' > in || framework_failure_

cat <<\EOF > splits_exp
1 1 1 1 1 1 1 1 1 1
2 2 2 1 2 1
2 3 2 2 1
2 4 3 1
2 5 3
2 5 3
7 3
7 3
9 1
9 1
10
EOF

seq 0 9 | tr -d '\n' > no_eol_in

cat <<\EOF > no_eol_splits_exp
1 1 1 1 1 1 1 1 1 1
2 2 2 2 2
3 3 3 1
4 4 2
5 5
6 4
7 3
8 2
9 1
10
10
EOF

for b in $(seq 10); do
  > splits
  > no_eol_splits
  for s in $(seq 11); do
    rm x??
    split ---io=$b -C$s in || fail=1
    cat x* > out || framework_failure_
    compare in out || fail=1
    stat -c %s x* | paste -s -d ' ' >> splits

    rm x??
    split ---io=$b -C$s no_eol_in || fail=1
    cat x* > out || framework_failure_
    cat xaa
    compare no_eol_in out || fail=1
    stat -c %s x* | paste -s -d ' ' >> no_eol_splits
  done
  compare splits_exp splits || fail=1
  compare no_eol_splits_exp no_eol_splits || fail=1
done

Exit $fail
