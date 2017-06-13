#!/bin/sh
# With POSIXLY_CORRECT, id must not print context=...

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
print_ver_ id

# We don't need selinux *FS* support to test id,
# but this is as good a witness as any, in general.
require_selinux_


# Require the context=... part by default.
id > out || fail=1
grep context= out || fail=1

# Require no context=... part in conforming mode.
POSIXLY_CORRECT=1 id > out || fail=1
grep context= out && fail=1

Exit $fail
