#!/bin/sh
# Ensure that rm -rf removes an empty-and-inaccessible directory.

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
print_ver_ rm
skip_if_root_

mkdir -m0 inacc || framework_failure_

# Also exercise the different code path that's taken for a directory
# that is empty (hence removable) and unreadable.
mkdir -m a-r -p a/unreadable


# This would fail for e.g., coreutils-5.93.
rm -rf inacc || fail=1
test -d inacc && fail=1

# This would fail for e.g., coreutils-5.97.
rm -rf a || fail=1
test -d a && fail=1

Exit $fail
