#!/bin/sh
# test multiple argument handling.

# Copyright (C) 2012-2017 Free Software Foundation, Inc.

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
print_ver_ readlink

touch regfile || framework_failure_
ln -s regfile link1 || framework_failure_

readlink link1 link1 || fail=1
returns_ 1 readlink link1 link2 || fail=1
returns_ 1 readlink link1 link2 link1 || fail=1
readlink -m link1 link2 || fail=1

printf '/1\0/1\0' > exp || framework_failure_
readlink -m --zero /1 /1 > out || fail=1
compare exp out || fail=1

# The largely redundant --no-newline option is ignored with multiple args.
# Note BSD's readlink suppresses all delimiters, even with multiple args,
# but that functionality was not thought useful.
readlink -n -m --zero /1 /1 > out || fail=1
compare exp out || fail=1

# Note the edge case that the last xargs run may not have a delimiter
rm out || framework_failure_
printf '/1\0/1\0/1' > exp || framework_failure_
printf '/1 /1 /1 ' | xargs -n2 readlink -n -m --zero >> out || fail=1
compare exp out || fail=1

Exit $fail
