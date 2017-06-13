#!/bin/sh
# Ensure that even when run from an inaccessible directory, du can still
# operate on accessible directories elsewhere.

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

# Before the switch to an fts-based implementation in coreutils 5.0.92,
# this test would fail.

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ du

# Skip this test if your system has neither the openat-style functions
# nor /proc/self/fd support with which to emulate them.
require_openat_support_

skip_if_root_

cwd=$(pwd)
mkdir -p no-x a/b || framework_failure_
cd no-x || framework_failure_
chmod 0 . || framework_failure_


du "$cwd/a" > /dev/null || fail=1

Exit $fail
