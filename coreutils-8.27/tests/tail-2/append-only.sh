#!/bin/sh
# Ensure that tail -f works on an append-only file
# Requires root access to do chattr +a, as well as an ext[23] or xfs file system

# Copyright (C) 2006-2017 Free Software Foundation, Inc.

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
print_ver_ tail
require_root_

# Terminate any background tail process
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

chattr_a_works=1
touch f
chattr +a f 2>/dev/null || chattr_a_works=0
( echo x > f ) 2>/dev/null && chattr_a_works=0
echo x >> f || chattr_a_works=0

if test $chattr_a_works = 0; then
  skip_ "chattr +a doesn't work on this file system"
fi


for mode in '' '---disable-inotify'; do
  sleep 1 & pid=$!
  tail --pid=$pid -f $mode f || fail=1
  cleanup_
done

chattr -a f 2>/dev/null

Exit $fail
