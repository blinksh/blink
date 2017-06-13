#!/bin/sh
# Ensure that du counts the size of an inaccessible directory.
# Copyright (C) 2007-2017 Free Software Foundation, Inc.

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
print_ver_ du
skip_if_root_

mkdir -p a/sub || framework_failure_


du -s a > exp || fail=1
chmod 0 a/sub || fail=1
# Expect failure, ignore diagnostics.
du -s a > out 2> /dev/null && fail=1

compare exp out || fail=1

# Same as above, but don't use -s, so we print
# an entry for the unreadable "sub", too.
chmod 700 a/sub || fail=1
du -k a > exp || fail=1
chmod 0 a/sub || fail=1
# Expect failure, ignore diagnostics.
du -k a > out 2> /dev/null && fail=1

compare exp out || fail=1

Exit $fail
