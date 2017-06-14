#!/bin/sh
# Make sure that 'mv file unwritable-file' prompts the user
# and that 'mv -f file unwritable-file' doesn't.

# Copyright (C) 2001-2017 Free Software Foundation, Inc.

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
print_ver_ mv
require_controlling_input_terminal_
skip_if_root_
trap '' TTIN # Ignore SIGTTIN

uname -s | grep 'BSD$' && skip_ 'known spurious failure on *BSD'

touch f g h i || framework_failure_
chmod 0 g i || framework_failure_


ls /dev/stdin >/dev/null 2>&1 \
  || skip_ 'there is no /dev/stdin file'

# work around a dash bug when redirecting
# from symlinked ttys in the background
tty=$(readlink -f /dev/stdin)

test -r "$tty" 2>&1 \
  || skip_ '/dev/stdin is not readable'

# Terminate any background processes
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

mv f g < $tty > out 2>&1 & pid=$!

# Test for the expected prompt; sleep upon non-match.
check_overwrite_prompt()
{
  local delay="$1"
  case "$(cat out)" in
    "mv: replace 'g', overriding mode 0000"*) ;;
    *) sleep $delay; return 1;;
  esac
}

# Wait for up to 12.7 seconds for the expected prompt.
retry_delay_ check_overwrite_prompt .1 7 || { fail=1; cat out; }

cleanup_

mv -f h i > out 2>&1 || fail=1
test -f i || fail=1
test -f h && fail=1

# Make sure there was no prompt.
case "$(cat out)" in
  '') ;;
  *) fail=1 ;;
esac

Exit $fail
