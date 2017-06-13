#!/bin/sh
# test 'install -Z -D' and 'install -Z -d'
# based on tests/mkdir/restorecon.sh

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
print_ver_ ginstall
require_selinux_

mkdir subdir || framework_failure_
ctx='root:object_r:tmp_t'
mls_enabled_ && ctx="$ctx:s0"
chcon "$ctx" subdir || framework_failure_
cd subdir

# Since in a tmp_t dir, dirs can be created as user_tmp_t ...
touch standard || framework_failure_
mkdir restored || framework_failure_
if restorecon restored 2>/dev/null; then
  # ... but when restored can be set to user_home_t
  # So ensure the type for these mkdir -Z cases matches
  # the directory type as set by restorecon.
  ginstall -Z standard single || fail=1
  ginstall -Z -d single_d || fail=1
  # Run these as separate processes in case global context
  # set for an arg, impacts on another arg
  # TODO: Have the defaultcon() vary over these directories
  for dst in single_d/existing/file multi/ple/file; do
    ginstall -Z -D standard "$dst" || fail=1
  done
  restored_type=$(get_selinux_type 'restored')
  test "$(get_selinux_type 'single')" = "$restored_type" || fail=1
  test "$(get_selinux_type 'single_d')" = "$restored_type" || fail=1
  test "$(get_selinux_type 'single_d/existing')" = "$restored_type" || fail=1
  test "$(get_selinux_type 'multi')" = "$restored_type" || fail=1
  test "$(get_selinux_type 'multi/ple')" = "$restored_type" || fail=1
fi
if test "$fail" = '1'; then
  ls -UZd standard restored
  ls -UZd single single_d single_d/existing multi multi/ple
fi

Exit $fail
