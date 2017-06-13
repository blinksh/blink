#!/bin/sh
# When reading a specified number of lines, ensure that the output
# file pointer is positioned just after those lines.

# Copyright (C) 2002-2017 Free Software Foundation, Inc.

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
print_ver_ head

(echo a; echo b) > in || framework_failure_
echo b > exp || framework_failure_

for i in -1 1; do
  (head -n $i >/dev/null; cat) < in > out || fail=1
  compare exp out || fail=1
done

# Exercise the (start_pos < pos) block in elide_tail_lines_seekable.
# So far, this is the only test to do that.
# Do that by creating a file larger than BUFSIZ (I've seen 128K) and
# elide a suffix of it (by line count) that is also larger than BUFSIZ.
# 50000 lines times 6 bytes per line gives us enough leeway even on a
# system with a BUFSIZ of 256K.
n_lines=50000
seq 70000 > in2 || framework_failure_
echo $n_lines > exp-n || framework_failure_

(head -n-$n_lines>/dev/null; wc -l) < in2 > n
compare exp-n n || fail=1

Exit $fail
