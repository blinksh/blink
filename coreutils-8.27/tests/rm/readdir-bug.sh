#!/bin/sh
# Exercise the Darwin/MacOS bug worked around on 2006-09-29,
# whereby rm would fail to remove all entries in a directory.

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

# Create a directory containing many files.
# What counts is a combination of the number of files and
# the lengths of their names.  For details, see
# http://lists.gnu.org/archive/html/bug-coreutils/2006-09/msg00326.html
mkdir b || framework_failure_
cd b || framework_failure_
for i in $(seq 1 250); do
  touch $(printf %040d $i) || framework_failure_
done
cd .. || framework_failure_


# On a buggy system, this would fail with the diagnostic,
# "cannot remove directory 'b': Directory not empty"
rm -rf b  || fail=1

test -d b && fail=1

Exit $fail
