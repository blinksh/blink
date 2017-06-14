#!/bin/sh
# test program group handling

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
print_ver_ timeout
require_trap_signame_
require_kill_group_

# construct a program group hierarchy as follows:
#  timeout-group - foreground group
#    group.sh - separate group
#      timeout.cmd - same group as group.sh
#
# We then send a SIGINT to the "separate group"
# to simulate what happens when a Ctrl-C
# is sent to the foreground group.

setsid true || skip_ "setsid required to control groups"

printf '%s\n' '#!'"$SHELL" > timeout.cmd || framework_failure_
cat >> timeout.cmd <<\EOF
trap 'touch int.received; exit' INT
touch timeout.running
count=$1
until test -e int.received || test $count = 0; do
  sleep 1
  count=$(expr $count - 1)
done
EOF
chmod a+x timeout.cmd

cat > group.sh <<EOF
#!$SHELL
trap '' INT
timeout --foreground 25 ./timeout.cmd 20&
wait
EOF
chmod a+x group.sh

check_timeout_cmd_running()
{
  local delay="$1"
  test -e timeout.running ||
    { sleep $delay; return 1; }
}

# Terminate any background processes
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

# Start above script in its own group.
# We could use timeout for this, but that assumes an implementation.
setsid ./group.sh & pid=$!
# Wait 6.3s for timeout.cmd to start
retry_delay_ check_timeout_cmd_running .1 6 || fail=1
# Simulate a Ctrl-C to the group to test timely exit
kill -INT -- -$pid
wait
test -e int.received || fail=1

rm -f int.received timeout.running


# Ensure cascaded timeouts work
# or more generally, ensure we timeout
# commands that create their own group
# This didn't work before 8.13.

start=$(date +%s)

# Note the first timeout must send a signal that
# the second is handling for it to be propagated to the command.
# SIGINT, SIGTERM, SIGALRM etc. are implicit.
timeout -sALRM 30 timeout -sINT 25 ./timeout.cmd 20 & pid=$!
# Wait 6.3s for timeout.cmd to start
retry_delay_ check_timeout_cmd_running .1 6 || fail=1
kill -ALRM $pid # trigger the alarm of the first timeout command
wait $pid
ret=$?
test $ret -eq 124 ||
  skip_ "timeout returned $ret. SIGALRM not handled?"
test -e int.received || fail=1

end=$(date +%s)

test $(expr $end - $start) -lt 20 ||
  skip_ "timeout.cmd didn't receive a signal until after sleep?"

Exit $fail
