#!/bin/sh
# Test "chmod =x" and the like.

# Copyright (C) 1999-2017 Free Software Foundation, Inc.

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

file=f
touch $file || framework_failure_

umask 005
for mode in =x =xX =Xx =x,=X =X,=x; do
  chmod a=r,$mode $file || fail=1
  case "$(ls -l $file)" in
    ---x--x---*) ;;
    *) fail=1; echo "after 'chmod $mode $file':"; ls -l $file ;;
  esac
done

Exit $fail
