#!/bin/sh
# Ensure that mkdir-p.c's fail-to-return-to-initial-working-directory
# causes immediate failure.  Also, ensure that we don't create
# subsequent, relative command-line arguments in the wrong place.

# Copyright (C) 2005-2017 Free Software Foundation, Inc.

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
skip_if_root_

mkdir no-access || framework_failure_
mkdir no-acce2s || framework_failure_
mkdir -p no-acce3s/d || framework_failure_

p=$(pwd)
(cd no-access && chmod 0 . && mkdir -p "$p/a/b" u/v) 2> /dev/null
test $? -eq 1 || fail=1
test -d "$p/a/b" || fail=1

# Same as above, but with a following *absolute* name, it should succeed
(cd no-acce2s && chmod 0 . && mkdir -p "$p/b/b" "$p/z") || fail=1
test -d "$p/b/b" && test -d "$p/z" || fail=1

# Same as above, but a trailing relative name in an unreadable directory
# whose parent is inaccessible.  coreutils 5.97 fails this test.
# Perform this test only if "." is on a local file system.
# Otherwise, it would fail e.g., on an NFS-mounted file system.
if is_local_dir_ .; then
  (cd no-acce3s/d && chmod a-r . && chmod a-rx .. &&
      mkdir -p a/b "$p/b/c" d/e && test -d a/b && test -d d/e) || fail=1
  test -d "$p/b/c" || fail=1
fi

b=$(ls "$p/a" | tr -d '\n')
# With coreutils-5.3.0, this would fail with $b=bu.
test "x$b" = xb || fail=1

Exit $fail
