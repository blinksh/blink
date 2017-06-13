#!/bin/sh
# Ensure that stty diagnoses invalid inputs, rather than silently misbehaving.

# Copyright (C) 2007-2017 Free Software Foundation, Inc.

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
print_ver_ stty
require_controlling_input_terminal_
require_trap_signame_

trap '' TTOU # Ignore SIGTTOU


saved_state=$(stty -g) || fail=1
stty $saved_state || fail=1

# Before coreutils-6.9.90, if stty were given an argument with 35 colons
# separating 36 hexadecimal strings, stty would fail to diagnose as invalid
# any number that was out of range as long as sscanf happened to
# overflow/wrap it back into the range of the corresponding type (either
# tcflag_t or cc_t).

# For each of the following, with coreutils-6.9 and earlier,
# stty would fail to diagnose the error on at least Solaris 10.
hex_2_64=10000000000000000
returns_ 1 stty $(echo $saved_state |sed 's/^[^:]*:/'$hex_2_64:/) \
  2>/dev/null || fail=1
returns_ 1 stty $(echo $saved_state |sed 's/:[0-9a-f]*$/:'$hex_2_64/) \
  2>/dev/null || fail=1

# Just in case either of the above mistakenly succeeds (and changes
# the state of our tty), try to restore the initial state.
stty $saved_state || fail=1

Exit $fail
