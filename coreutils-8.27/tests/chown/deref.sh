#!/bin/sh
# For coreutils-5.2.1 and earlier, chown --dereference would skip
# symlinks having owner/group matching the specified owner/group.

# Copyright (C) 2004-2017 Free Software Foundation, Inc.

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
print_ver_ chown

ln -s no-such dangle || framework_failure_


set _ $(ls -ldo dangle); shift; user=$3

# With 5.2.1 and earlier, this command would mistakenly succeed.
chown --dereference $user dangle 2> out1 && fail=1
sed 's/: [^:]*$//' out1 > out

cat <<\EOF > exp || fail=1
chown: cannot dereference 'dangle'
EOF

compare exp out || fail=1

Exit $fail
