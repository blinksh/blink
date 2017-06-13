#!/bin/sh
# demonstrate that stat handles trailing slashes correctly

# Copyright (C) 2009-2017 Free Software Foundation, Inc.

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
print_ver_ stat

touch file || framework_failure_
mkdir dir || framework_failure_
ln -s file link1 || framework_failure_
ln -s dir link2 || framework_failure_

cat <<EOF > exp || framework_failure_
link1
symbolic link
directory
directory
EOF

# This failed on Solaris 9 for coreutils 8.0.
stat --format=%n link1 > out || fail=1
returns_ 1 stat --format=%n link1/ >> out || fail=1

stat --format=%F link2 >> out || fail=1
stat -L --format=%F link2 >> out || fail=1
stat --format=%F link2/ >> out || fail=1

compare exp out || fail=1

Exit $fail
