#!/bin/sh
# make sure that dd doesn't allocate memory unnecessarily

# Copyright (C) 2013-2017 Free Software Foundation, Inc.

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

# Determine basic amount of memory needed.
echo . > f || framework_failure_
vm=$(get_min_ulimit_v_ timeout 10 dd if=f of=f2 status=none) \
  || skip_ "this shell lacks ulimit support"
rm f f2 || framework_failure_

# count and skip are zero, we don't need to allocate memory
(ulimit -v $vm && dd  bs=30M count=0) || fail=1
(ulimit -v $vm && dd ibs=30M count=0) || fail=1
(ulimit -v $vm && dd obs=30M count=0) || fail=1

check_dd_seek_alloc() {
  local file="$1"
  local buf="$2"
  test "$file" = 'in' && { dd_file=if; dd_op=skip; }
  test "$file" = 'out' && { dd_file=of; dd_op=seek; }
  test "$buf" = 'in' && { dd_buf=ibs; }
  test "$buf" = 'out' && { dd_buf=obs; }
  test "$buf" = 'both' && { dd_buf=bs; }

  # Provide input to the "tape"
  timeout 10 dd count=1 if=/dev/zero of=tape&

  # Allocate buffer and read from the "tape"
  (ulimit -v $vm \
     && timeout 10 dd $dd_buf=30M $dd_op=1 count=0 $dd_file=tape)
  local ret=$?

  # Be defensive in case the tape reader is blocked for some reason
  test $ret = 124 && framework_failure_

  # This should happen without delay,
  # and is used to ensure we've not multiple writers to the "tape"
  wait

  # We want the "tape" reader to fail iff allocating
  # a large buffer corresponding to the file being read
  case "$file$buf" in
    inout|outin) test $ret = 0;;
    *) test $ret != 0;;
  esac
}

# Use a fifo for which seek fails, but read does not.
# For non seekable output we need to allocate a buffer
# when simulating seeking with a read.
if mkfifo tape; then
  for file in 'in' 'out'; do
    for buf in 'both' 'in' 'out'; do
      check_dd_seek_alloc "$file" "$buf" || fail=1
    done
  done
fi

Exit $fail
