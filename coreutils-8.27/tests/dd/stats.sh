#!/bin/sh
# Check stats output for SIG{INFO,USR1} and status=progress

# Copyright (C) 2014-2017 Free Software Foundation, Inc.

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
require_trap_signame_

kill -l | grep 'INFO' && SIGINFO='INFO' || SIGINFO='USR1'

# This to avoid races in the USR1 case
# as the dd process will terminate by default until
# it has its handler enabled.
trap '' $SIGINFO

mkfifo_or_skip_ fifo

# Terminate any background processes
cleanup_()
{
  kill $pid  2>/dev/null
  kill $pid2 2>/dev/null
  wait
}

for open in '' '1'; do
  > err || framework_failure_

  # Run dd with the fullblock iflag to avoid short reads
  # which can be triggered by reception of signals
  dd iflag=fullblock if=/dev/zero of=fifo count=50 bs=5000000 2>err & pid=$!

  # Note if we sleep here we give dd a chance to exec and block on open.
  # Otherwise we're probably testing SIG_IGN in the forked shell or early dd.
  test "$open" && sleep .1

  # dd will block on open until fifo is opened for reading.
  # Timeout in case dd goes away erroneously which we check for below.
  timeout 20 sh -c 'wc -c < fifo > nwritten' & pid2=$!

  # Send lots of signals immediately to ensure dd not killed due
  # to race setting handler, or blocking on open of fifo.
  # Many signals also check that short reads are handled.
  until ! kill -s $SIGINFO $pid 2>/dev/null; do
    sleep .01
  done

  wait

  # Ensure all data processed and at least last status written
  grep '250000000 bytes (250 MB, 238 MiB) copied' err || { cat err; fail=1; }
done

progress_output()
{
  { sleep $1; echo 1; } | dd bs=1 status=progress of=/dev/null 2>err
  # Progress output should be for "byte copied", while final is "bytes ..."
  grep 'byte copied' err
}
retry_delay_ progress_output 1 4 || { cat err; fail=1; }

Exit $fail
