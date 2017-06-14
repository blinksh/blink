#!/bin/sh
# Verify that internal failure in nice gives exact status.

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
print_ver_ nice


# These tests verify exact status of internal failure.
returns_ 125 nice -n 1 || fail=1 # missing command
returns_ 125 nice --- || fail=1 # unknown option
returns_ 125 nice -n 1a || fail=1 # invalid adjustment
returns_ 2 nice sh -c 'exit 2' || fail=1 # exit status propagation
returns_ 126 nice . || fail=1 # invalid command
returns_ 127 nice no_such || fail=1 # no such command

Exit $fail
