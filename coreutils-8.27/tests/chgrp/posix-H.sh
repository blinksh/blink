#!/bin/sh
# Test POSIX-mandated -H option.

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
print_ver_ chgrp
require_membership_in_two_groups_
require_local_dir_

set _ $groups; shift
g1=$1
g2=$2

mkdir 1 2 3 || framework_failure_
touch 1/1F 2/2F 3/3F || framework_failure_
ln -s 1 1s || framework_failure_
ln -s ../3 2/2s || framework_failure_
chgrp -R $g1 1 2 3 || framework_failure_


chgrp --preserve-root -H -R $g2 1s 2 || fail=1

# These must have group $g2.
# =========================
changed='
1
1/1F
2
2/2F
3
'
for i in $changed; do
  # Filter out symlinks (entries that end in 's'), since it's not
  # possible to change their group/owner information on some systems.
  case $i in *s) continue;; esac
  set _ $(ls -dgn $i); shift
  group=$3
  test $group = $g2 || fail=1
done

# These must have group $g1.
# =========================
not_changed='
1s
2/2s
3/3F
'
for i in $not_changed; do
  # Filter out symlinks (entries that end in 's'), since it's not
  # possible to change their group/owner information on some systems.
  case $i in *s) continue;; esac
  set _ $(ls -dgn $i); shift
  group=$3
  test $group = $g1 || fail=1
done

Exit $fail
