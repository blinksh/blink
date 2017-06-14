#!/bin/sh
# Ensure that "id" works with numeric user ids
# Copyright (C) 2013-2017 Free Software Foundation, Inc.

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

uid=$(id -u) || fail=1
user=$(id -nu) || fail=1

# Ensure the empty user spec is discarded
returns_ 1 id '' || fail=1

for mode in '' '-G' '-g'; do
  id $mode $user > user_out || fail=1 # lookup name for comparison

  id $mode $uid > uid_out || fail=1   # lookup name "$uid" before id "$uid"
  compare user_out uid_out || fail=1

  id $mode +$uid > uid_out || fail=1  # lookup only id "$uid"
  compare user_out uid_out || fail=1
done

Exit $fail
