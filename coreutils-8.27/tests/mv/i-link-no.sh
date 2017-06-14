#!/bin/sh
# Show that mv doesn't preserve links to files the user has declined to move.

# Copyright (C) 2002-2017 Free Software Foundation, Inc.

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
print_ver_ mv

mkdir a b || framework_failure_
echo foo > a/foo || framework_failure_
ln a/foo a/bar || framework_failure_
echo FUBAR > b/FUBAR || framework_failure_
ln b/FUBAR b/bar || framework_failure_
chmod a-w b/bar || framework_failure_
echo n > no || framework_failure_


mv a/bar a/foo b < no > out 2> err || fail=1
touch exp
touch exp_err

compare exp out || fail=1
compare exp_err err || fail=1

case "$(cat b/foo)" in
  foo) ;;
  *) fail=1;;
esac

Exit $fail
