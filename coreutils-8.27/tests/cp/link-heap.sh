#!/bin/sh
# ensure that cp --preserve=link --link doesn't waste heap

# Copyright (C) 2008-2017 Free Software Foundation, Inc.

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
print_ver_ cp
expensive_

# Determine basic amount of memory needed for 'cp -al'.
touch f || framework_failure_
vm=$(get_min_ulimit_v_ cp -al f f2) \
  || skip_ "this shell lacks ulimit support"
rm f f2 || framework_failure_

a=$(printf %031d 0)
b=$(printf %031d 1)
(mkdir $a \
   && cd $a \
   && seq --format=%031g 10000 |xargs touch \
   && seq --format=d%030g 10000 |xargs mkdir ) || framework_failure_
cp -al $a $b || framework_failure_
mkdir e || framework_failure_
mv $a $b e || framework_failure_

# Allow cp(1) to use 4MiB more virtual memory than for the above trivial case.
(ulimit -v $(($vm+4000)) && cp -al e f) || fail=1

Exit $fail
