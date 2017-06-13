#!/bin/sh
# trigger a bug that would make parallel sort use 100% of one or more
# CPU while blocked on output.

# Copyright (C) 2010-2017 Free Software Foundation, Inc.

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
print_ver_ sort

# This isn't terribly expensive, but it must not be run under heavy load.
# Since the "very expensive" tests are already run only with -j1, adding
# this test to the list ensures it still gets _some_ (albeit minimal)
# coverage while not causing false-positive failures in day to day runs.
very_expensive_

grep '^#define HAVE_PTHREAD_T 1' "$CONFIG_HEADER" > /dev/null ||
  skip_ 'requires pthreads'

# Terminate any background processes
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

seq 100000 > in || framework_failure_
mkfifo_or_skip_ fifo

# Arrange for sort to require 8.0+ seconds of wall-clock time,
# while actually using far less than 1 second of CPU time.
(for i in $(seq 80); do read line; echo $i; sleep .1; done
  cat > /dev/null) < fifo & pid=$!

# However, under heavy load, it can easily take more than
# one second of CPU time, so set a permissive limit:
ulimit -t 7
sort --parallel=2 in > fifo || fail=1

Exit $fail
