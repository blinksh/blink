#!/bin/sh
# Ensure that rm works even when run from a directory
# for which the user has no access at all.

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
print_ver_ rm

# Skip this test if your system has neither the openat-style functions
# nor /proc/self/fd support with which to emulate them.
require_openat_support_
skip_if_root_

p=$(pwd)
mkdir abs1 abs2 no-access || framework_failure_


set +x
(cd no-access; chmod 0 . && rm -r "$p/abs1" rel "$p/abs2") 2> out && fail=1
test -d "$p/abs1" && fail=1
test -d "$p/abs2" && fail=1

cat <<\EOF > exp || fail=1
rm: cannot remove 'rel': Permission denied
EOF

# AIX 4.3.3 fails with a different diagnostic.
# Transform their diagnostic
#   ...: The file access permissions do not allow the specified action.
# to the expected one:
sed 's/: The file access permissions.*/: Permission denied/'<out>o1;mv o1 out

compare exp out || fail=1

Exit $fail
