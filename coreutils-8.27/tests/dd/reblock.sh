#!/bin/sh
# test dd reblocking vs. bs=

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
print_ver_ dd

# 2 short reads -> 1 full write + 1 partial write
cat <<\EOF > exp-reblock || framework_failure_
0+2 records in
1+1 records out
4 bytes copied
EOF

# 2 short reads -> 2 partial writes
cat <<\EOF > exp-no-reblock || framework_failure_
0+2 records in
0+2 records out
4 bytes copied
EOF


# Use a fifo rather than a pipe in the tests below
# so that the producer (printf subshell) will wait
# until the consumer (dd) opens the fifo therefore
# increasing the chance that dd will read the data
# from each printf separately.
mkfifo_or_skip_ dd.fifo

dd_reblock_1()
{
  local delay="$1"

  # ensure that dd reblocks when bs= is not specified
  dd ibs=3 obs=3 if=dd.fifo > out 2> err&
  (printf 'ab'; sleep $delay; printf 'cd') > dd.fifo
  wait #for dd to complete
  sed 's/,.*//' err > k && mv k err
  compare exp-reblock err
}

retry_delay_ dd_reblock_1 .1 6 || fail=1

dd_reblock_2()
{
  local delay="$1"

  # Demonstrate that bs=N supersedes even following ibs= and obs= settings.
  dd bs=3 ibs=1 obs=1 if=dd.fifo > out 2> err&
  (printf 'ab'; sleep $delay; printf 'cd') > dd.fifo
  wait #for dd to complete
  sed 's/,.*//' err > k && mv k err
  compare exp-no-reblock err
}

retry_delay_ dd_reblock_2 .1 6 || fail=1

Exit $fail
