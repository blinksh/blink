#!/bin/sh
# SMACK test for the id-command.
# Derived from tests/id/context.sh and tests/id/no-context.sh.
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
print_ver_ id

require_smack_

# Check the string "context=" presence without specified user.
id > out || fail=1
grep 'context=' out || { cat out; fail=1; }

# Check context=" is absent without specified user in conforming mode.
POSIXLY_CORRECT=1 id > out || fail=1
grep 'context=' out && fail=1

# Check the string "context=" absence with specified user.
# But if the current user is nameless, skip this part.
id -nu > /dev/null && id $(id -nu) > out
grep 'context=' out && fail=1

Exit $fail
