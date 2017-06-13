#!/bin/sh
# Make sure chmod mode arguments of the form A=B work properly.
# Before fileutils-4.1.2, some of them didn't.
# Also, before coreutils-5.3.1, =[ugo] sometimes didn't work.

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
print_ver_ chmod

touch f || framework_failure_


expected_u=-rwx------
expected_g=----rwx---
expected_o=-------rwx

for src in u g o; do
  for dest in u g o; do
    test $dest = $src && continue
    chmod a=,$src=rwx,$dest=$src,$src= f || fail=1
    actual_perms=$(ls -l f|cut -b-10)
    expected_perms=$(eval 'echo $expected_'$dest)
    test "$actual_perms" = "$expected_perms" || fail=1
  done
done

umask 027
chmod a=,u=rwx,=u f || fail=1
actual_perms=$(ls -l f|cut -b-10)
test "$actual_perms" = "-rwxr-x---" || fail=1

Exit $fail
