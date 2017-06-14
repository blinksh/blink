#!/bin/sh
# Ensure that cat outputs processed data immediately.

# Copyright (C) 2009-2017 Free Software Foundation, Inc.

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
print_ver_ cat

# Use a fifo rather than a pipe in the tests below
# so that the producer (cat) will wait until the
# consumer (dd) opens the fifo therefore increasing
# the chance that dd will read the data from each
# write separately.
mkfifo_or_skip_ fifo

# Terminate any background cp process
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

echo 1 > exp

cat_buf_1()
{
  local delay="$1"

  > out || framework_failure_
  dd count=1 if=fifo > out & pid=$!
  (echo 1; sleep $delay; echo 2) | cat -v > fifo
  wait $pid
  compare exp out
}

retry_delay_ cat_buf_1 .1 6 || fail=1

Exit $fail
