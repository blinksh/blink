#!/bin/sh
# Make sure cp -p doesn't "restore" permissions it shouldn't (Bug#9170).

# Copyright 2011-2017 Free Software Foundation, Inc.

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
print_ver_ cp

umask 002
mkdir -p -m ug-s,u=rwx,g=rwx,o=rx src/dir || fail=1
mkdir -p -m ug-s,u=rwx,g=,o= dst/dir || fail=1

cp -r src/. dst/ || fail=1

mode=$(stat --p=%A dst/dir)
test "$mode" = drwx------ || fail=1

Exit $fail
