#!/bin/sh
# Validate kill operation

# Copyright (C) 2015-2017 Free Software Foundation, Inc.

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
print_ver_ kill

# params required
returns_ 1 env kill || fail=1
returns_ 1 env kill -TERM || fail=1

# Invalid combinations
returns_ 1 env kill -l -l || fail=1
returns_ 1 env kill -l -t || fail=1
returns_ 1 env kill -l -s 1 || fail=1
returns_ 1 env kill -t -s 1 || fail=1

# signal sending
returns_ 1 env kill -0 no_pid || fail=1
env kill -0 $$ || fail=1
env kill -s0 $$ || fail=1
env kill -n0 $$ || fail=1 # bash compat
env kill -CONT $$ || fail=1
env kill -Cont $$ || fail=1
returns_ 1 env kill -cont $$ || fail=1
env kill -0 -1 || fail=1 # to group

# table listing
env kill -l || fail=1
env kill -t || fail=1
env kill -L || fail=1 # bash compat
env kill -t TERM HUP || fail=1

# Verify (multi) name to signal number and vice versa
SIGTERM=$(env kill -l HUP TERM | tail -n1) || fail=1
test $(env kill -l "$SIGTERM") = TERM || fail=1

# Verify we only consider the lower "signal" bits,
# to support ksh which just adds 256 to the signal value
STD_TERM_STATUS=$(expr "$SIGTERM" + 128)
KSH_TERM_STATUS=$(expr "$SIGTERM" + 256)
test $(env kill -l $STD_TERM_STATUS $KSH_TERM_STATUS | uniq) = TERM || fail=1

# Verify invalid signal spec is diagnosed
returns_ 1 env kill -l -1 || fail=1
returns_ 1 env kill -l -1 0 || fail=1
returns_ 1 env kill -l INVALID TERM || fail=1

Exit $fail
