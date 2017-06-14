#!/bin/sh
# Test "rm -ir".

# Copyright (C) 1997-2017 Free Software Foundation, Inc.

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

t=t
mkdir -p $t $t/a $t/b $t/c || framework_failure_
> $t/a/a || framework_failure_
> $t/b/bb || framework_failure_
> $t/c/cc || framework_failure_

cat <<EOF > in
y
y
y
y
y
y
y
y
n
n
n
EOF

# Remove all but one of a, b, c -- I doubt that this test can portably
# determine which one was removed based on order of dir entries.
# This is a good argument for switching to a dejagnu-style test suite.
rm --verbose -i -r $t < in > /dev/null 2>&1 || fail=1

# $t should not have been removed.
test -d $t || fail=1

# There should be only one directory left.
case $(echo $t/*) in
  $t/[abc]) ;;
  *) fail=1 ;;
esac

Exit $fail
