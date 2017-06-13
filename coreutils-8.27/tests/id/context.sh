#!/bin/sh
# Ensure that "id" outputs SELinux context only without specified user
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
print_ver_ id
# Require selinux - when selinux is disabled, id never prints scontext.
require_selinux_


# Check without specified user, context string should be present.
id | grep context= >/dev/null || fail=1

# Check with specified user, no context string should be present.
# But if the current user is nameless, skip this part.
name=$(id -nu) || { test $? -ne 1 && fail=1; }
if test "$name"; then
  id "$name" > id_name || fail=1
  grep context= id_name >/dev/null && fail=1
fi

Exit $fail
