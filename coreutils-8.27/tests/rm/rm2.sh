#!/bin/sh
# exercise another small part of remove.c

# Copyright (C) 2002-2017 Free Software Foundation, Inc.

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
print_ver_ rm
skip_if_root_

mkdir -p a/0 || framework_failure_
mkdir -p a/1/2 b/3 || framework_failure_
mkdir a/2 a/3 || framework_failure_
chmod u-x a/1 b || framework_failure_


# Exercise two separate code paths -- though both result
# in the same sort of diagnostic.
# Both of these should fail.
rm -rf a b > out 2>&1 && fail=1
cat <<\EOF > exp
rm: cannot remove 'a/1': Permission denied
rm: cannot remove 'b': Permission denied
EOF

cat <<\EOF > exp-solaris
rm: cannot remove 'a/1/2': Permission denied
rm: cannot remove 'b/3': Permission denied
EOF

cmp out exp > /dev/null 2>&1 \
    || { cmp out exp-solaris > /dev/null 2>&1 || fail=1; }
test $fail = 1 && compare exp out

test -d a/0 && fail=1
test -d a/1 || fail=1
test -d a/2 && fail=1
test -d a/3 && fail=1

chmod u+x b
test -d b/3 || fail=1

Exit $fail
