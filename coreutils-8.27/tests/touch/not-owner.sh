#!/bin/sh
# Make sure that touch gives reasonable diagnostics when applied
# to an unwritable directory owned by some other user.

# Copyright (C) 2003-2017 Free Software Foundation, Inc.

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
print_ver_ touch

if env -- test -w /; then
  skip_ you have write access to /.
fi

if env -- test -O / || env -- test -G /; then
  skip_ "you own /."
fi

skip_if_root_


# Before fileutils-4.1, we'd get the following misleading
# diagnostic instead of '...: Permission denied'.
# touch: creating '/': Is a directory
touch / > out 2>&1 && fail=1

# On SunOS4, EPERM is 'Not owner'.
# On some *BSD systems it's 'Operation not permitted'.
# On a system where root file system is mounted read-only
# it's 'Read-only file system'.
for msg in 'Not owner' 'Operation not permitted' 'Permission denied' \
           'Read-only file system'; do
  cat > exp <<EOF
touch: setting times of '/': $msg
EOF

  cmp out exp > /dev/null 2>&1 && { match=1; break; }
done
test "$match" = 1 || fail=1

test $fail = 1 && compare exp out

Exit $fail
