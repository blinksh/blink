#!/bin/sh
# Test "mkdir -p" with default ACLs.

# Copyright (C) 1997-2017 Free Software Foundation, Inc.

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

require_setfacl_

mkdir d || framework_failure_
setfacl -d -m group::rwx d || framework_failure_
umask 077

mkdir --parents d/e || fail=1
ls_l=$(ls -ld d/e) || fail=1
case $ls_l in
  d???rw[sx]*) ;;
  *) fail=1 ;;
esac

Exit $fail
