#!/bin/sh
# Test "rm -r --verbose".

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

mkdir t t/a t/a/b || framework_failure_
> t/a/f || framework_failure_
> t/a/b/g || framework_failure_

# FIXME: if this fails, it's a framework failure
cat <<\EOF | sort > t/E || framework_failure_
removed directory 't/a'
removed directory 't/a/b'
removed 't/a/b/g'
removed 't/a/f'
EOF

# Note that both the expected output (above) and the actual output lines
# are sorted, because directory entries may be processed in arbitrary order.
rm --verbose -r t/a | sort > t/O || fail=1

if test -d t/a; then
  fail=1
fi

# Compare expected and actual output.
cmp t/E t/O || fail=1

Exit $fail
