#!/bin/sh
# a basic test of rm -ri

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

mkdir -p d/e || framework_failure_
cat <<EOF > in || framework_failure_
y
y
y
EOF

cat <<\EOF > exp || framework_failure_
rm: descend into directory 'd'
rm: remove directory 'd/e'
rm: remove directory 'd'
EOF


rm -ir d < in > out 2>&1 || fail=1

# Given input like 'rm: ...? rm: ...? ' (no trailing newline),
# the 'head...' part of the pipeline below removes the trailing space, so
# that sed doesn't have to deal with a line lacking a terminating newline.
# This avoids a bug whereby some vendor-provided (Tru64) versions of sed
# would mistakenly tack a newline onto the end of the output.
tr '?' '\n' < out | head --bytes=-1 | sed 's/^ //' > o2
mv o2 out

# Make sure it's been removed.
test -d d && fail=1

compare exp out || fail=1

Exit $fail
