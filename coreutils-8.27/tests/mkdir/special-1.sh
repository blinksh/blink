#!/bin/sh
# verify that mkdir honors special bits in MODE

# Copyright (C) 2000-2017 Free Software Foundation, Inc.

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
print_ver_ mkdir

set_mode_string=u=rwx,g=rx,o=w,-s,+t
output_mode_string=drwxr-x-wT

tmp=t
mkdir -m$set_mode_string $tmp || fail=1

test -d $tmp || fail=1
mode=$(ls -ld $tmp|cut -b-10)
case "$mode" in
  $output_mode_string) ;;
  *) fail=1 ;;
esac

rmdir $tmp || fail=1
tmp2=$tmp/sub

# This should fail.
returns_ 1 mkdir -m$set_mode_string $tmp2 2> /dev/null || fail=1

# Now test the --parents option.
mkdir --parents -m$set_mode_string $tmp2 || fail=1

test -d $tmp2 || fail=1
mode=$(ls -ld $tmp2|cut -b-10)
case "$mode" in
  $output_mode_string) ;;
  *) fail=1 ;;
esac

Exit $fail
