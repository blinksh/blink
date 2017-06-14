#!/bin/sh
# ensure that du and wc handle --files0-from=DIR

# Copyright (C) 2011-2017 Free Software Foundation, Inc.

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
print_ver_ du wc

mkdir dir

# Skip this test if reading from a directory succeeds.
# In that case, using --files0-from=dir would yield garbage,
# interpreting the directory entry as a sequence of
# NUL-separated file names.
cat dir > /dev/null && skip_ "cat dir/ succeeds"

for prog in du wc; do
  $prog --files0-from=dir > /dev/null 2>err && fail=1
  printf "$prog: dir:\n" > exp || fail=1
  # The diagnostic string is usually "Is a directory" (ENOTDIR),
  # but accept a different string or errno value.
  sed "s/dir:.*/dir:/" err > k; mv k err
  compare exp err || fail=1
done

Exit $fail
