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

mkdir -p b/a/p b/c b/d || framework_failure_
chmod ug-w b/a || framework_failure_


# This should fail.
rm -rf b > out 2>&1 && fail=1
cat <<\EOF > exp
rm: cannot remove directory 'b/a/p': Permission denied
EOF

# On some systems, rm doesn't have enough information to
# say it's a directory.
cat <<\EOF > exp2
rm: cannot remove 'b/a/p': Permission denied
EOF

cmp out exp > /dev/null 2>&1 || {
  cmp out exp2 || fail=1
  }
test $fail = 1 && compare exp out

test -d b/a/p || fail=1
test -d b/c && fail=1
test -d b/d && fail=1

Exit $fail
