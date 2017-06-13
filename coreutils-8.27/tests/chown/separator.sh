#!/bin/sh
# Make sure "chown USER:GROUP FILE" works, and similar tests with separators.

# Copyright (C) 2004-2017 Free Software Foundation, Inc.

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
print_ver_ chown

id_u=$(id -u) || framework_failure_
test -n "$id_u" || framework_failure_

id_un=$(id -un) || framework_failure_
test -n "$id_un" || framework_failure_

id_g=$(id -g) || framework_failure_
test -n "$id_g" || framework_failure_

id_gn=$(id -gn) || framework_failure_
test -n "$id_gn" || framework_failure_

# Systems with both local and external groups with conflicting IDs,
# were seen to fail this test erroneously with EPERM errors.
test $(getent group | grep "^$id_gn:" | wc -l) = 1 ||
  skip_ "group '$id_gn' not biunique: " \
        "$(getent group | grep "^$id_gn:" | tr '\n' ',')"

# FreeBSD 6.x's getgrnam fails to look up a group name containing
# a space. On such a system, skip this test if the group name contains
# a byte not in the portable filename character set.
case $host_triplet in
  *-freebsd6.*)
    case $id_gn in
      *[^a-zA-Z0-9._-]*) skip_ "invalid group name: $id_gn";;
    esac;;
  *) ;;
esac


chown '' . || fail=1

for u in $id_u "$id_un" ''; do
  for g in $id_g "$id_gn" ''; do
    case $u$g in
      *.*) seps=':' ;;
      *)   seps=': .' ;;
    esac
    for sep in $seps; do
      case $u$sep$g in
        [0-9]*$sep) returns_ 1 chown "$u$sep$g" . 2>/dev/null || fail=1 ;;
        *) chown "$u$sep$g" . || fail=1 ;;
      esac
    done
  done
done

Exit $fail
