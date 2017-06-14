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

mkdir -p z || framework_failure_
cd z || framework_failure_
touch empty empty-u || framework_failure_
echo not-empty > fu
ln -s empty-f slink
ln -s . slinkdot
mkdir d du || framework_failure_
chmod u-w fu du empty-u || framework_failure_
cd ..


cat <<EOF > in
y
y
y
y
y
y
y
y
y
EOF

# Both of these should fail.
rm -ir z < in > out 2>&1 || fail=1

# Given input like 'rm: ...? rm: ...? ' (no trailing newline),
# the 'head...' part of the pipeline below removes the trailing space, so
# that sed doesn't have to deal with a line lacking a terminating newline.
# This avoids a bug whereby some vendor-provided (Tru64) versions of sed
# would mistakenly tack a newline onto the end of the output.
tr '?' '\n' < out | head --bytes=-1 | sed 's/^ //' |sort > o2
mv o2 out

sort <<EOF > exp || fail=1
rm: descend into directory 'z'
rm: remove regular empty file 'z/empty'
rm: remove write-protected regular file 'z/fu'
rm: remove write-protected regular empty file 'z/empty-u'
rm: remove symbolic link 'z/slink'
rm: remove symbolic link 'z/slinkdot'
rm: remove directory 'z/d'
rm: remove write-protected directory 'z/du'
rm: remove directory 'z'
EOF

compare exp out || fail=1

test -d z && fail=1

Exit $fail
