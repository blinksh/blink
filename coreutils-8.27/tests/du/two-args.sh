#!/bin/sh
# Make sure 'du d/1 d/2' works.
# That command failed with du from fileutils-4.0q.

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
print_ver_ du

# Run this test from a sub-directory one level deeper than normal,
# so that the "du .." below doesn't traverse sibling directories
# that may be inaccessible due concurrently-running tests.
mkdir sub || framework_failure_
cd sub || framework_failure_

t=t
mkdir -p $t/1 $t/2 || framework_failure_

test -d $t || fail=1
du $t/1 $t/2 > /dev/null || fail=1

# Make sure 'du . $t' and 'du .. $t' work.
# These would fail prior to fileutils-4.0y.
du . $t > /dev/null || fail=1
du .. $t > /dev/null || fail=1

Exit $fail
