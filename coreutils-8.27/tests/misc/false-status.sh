#!/bin/sh
# ensure that false exits nonzero even with --help or --version
# and ensure that true exits nonzero when it can't write --help or --version

# Copyright (C) 2003-2017 Free Software Foundation, Inc.

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
print_ver_ false true

returns_ 1 env false --version > /dev/null || fail=1
returns_ 1 env false --help > /dev/null || fail=1

if test -w /dev/full && test -c /dev/full; then
  returns_ 1 env true --version > /dev/full || fail=1
  returns_ 1 env true --help > /dev/full || fail=1
fi

Exit $fail
