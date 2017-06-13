#!/bin/sh
# Ensure that cp --parents works properly with a preexisting dest. directory

# Copyright (C) 2008-2017 Free Software Foundation, Inc.

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
print_ver_ cp

working_umask_or_skip_
# cp -p gives ENOTSUP on NFS on Linux 2.6.9 at least
require_local_dir_

mkdir -p a/b/c a/b/d e || framework_failure_
touch a/b/c/foo a/b/d/foo || framework_failure_
cp -p --parent a/b/c/foo e || framework_failure_

# Make permissions of e/a different, so that we exercise the
# code in cp -p --parents that propagates permissions even
# to a destination directory that it doesn't create.
chmod g-rx e/a e/a/b || framework_failure_

cp -p --parent a/b/d/foo e || fail=1

# Ensure that permissions on just-created directory, e/a/,
# are the same as those on original, a/.

# The sed filter maps any 's' from an inherited set-GID bit
# to the usual 'x'.  Otherwise, under unusual circumstances, this
# test would fail with e.g., drwxr-sr-x != drwxr-xr-x .
# For reference, the unusual circumstances is: build dir is set-gid,
# so "a/" inherits that.  However, when the user does not belong to
# the group of the build directory, chmod ("a/e", 02755) returns 0,
# yet fails to set the S_ISGID bit.
for dir in a a/b a/b/d; do
  test $(stat --printf %A $dir|sed s/s/x/g) \
     = $(stat --printf %A e/$dir|sed s/s/x/g) ||
  fail=1
done

Exit $fail
