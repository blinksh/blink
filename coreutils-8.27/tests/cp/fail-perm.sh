#!/bin/sh

# Copyright (C) 2000-2017 Free Software Foundation, Inc.

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
print_ver_ cp
skip_if_root_

chmod g-s . || framework_failure_
mkdir D D/D || framework_failure_
touch D/a || framework_failure_
chmod 0 D/a || framework_failure_
chmod u=rx,go=,-st D || framework_failure_


# This is expected to exit non-zero, because it can't read D/a.
returns_ 1 cp -pR D DD > /dev/null 2>&1 || fail=1

# Permissions on DD must be 'dr-x------'

mode=$(ls -ld DD|cut -b-10)
test "$mode" = dr-x------ || fail=1

chmod 0 D
ln -s D/D symlink
touch F
cat > exp <<\EOF
cp: failed to access 'symlink': Permission denied
EOF

cp F symlink 2> out && fail=1
# HPUX appears to fail with EACCES rather than EPERM.
# Transform their diagnostic
#   ...: The file access permissions do not allow the specified action.
# to the expected one:
sed 's/: The file access permissions.*/: Permission denied/'<out>o1;mv o1 out
compare exp out || fail=1

cp --target-directory=symlink F 2> out && fail=1
sed 's/: The file access permissions.*/: Permission denied/'<out>o1;mv o1 out
compare exp out || fail=1

chmod 700 D

Exit $fail
