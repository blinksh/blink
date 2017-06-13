#!/bin/sh
# Demonstrate that when moving a symlink onto a hardlink-to-that-symlink,
# an error is presented.  Depending on your kernel (e.g., Linux, Solaris,
# but not NetBSD), prior to coreutils-8.16, the mv would successfully perform
# a no-op.  I.e., surprisingly, mv s1 s2 would succeed, yet fail to remove s1.

# Copyright (C) 2012-2017 Free Software Foundation, Inc.

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

# Create a file f, and a symlink s1 to that file.
touch f || framework_failure_
ln -s f s2 || framework_failure_

# Attempt to create a hard link to that symlink.
# On some systems, it's not possible: they create a hard link to the referent.
ln s2 s1 || framework_failure_

# If s1 is not a symlink, skip this test.
test -h s1 \
  || skip_ your kernel or file system cannot create a hard link to a symlink

for opt in '' --backup; do

  if test "$opt" = --backup; then
    mv $opt s1 s2 > out 2>&1 || fail=1
    compare /dev/null out || fail=1

    # Ensure that s1 is gone.
    test -e s1 && fail=1

    # With --backup, ensure that the backup file was created.
    ref=$(readlink s2~) || fail=1
    test "$ref" = f || fail=1
  else
    echo "mv: 's1' and 's2' are the same file" > exp
    mv $opt s1 s2 2>err && fail=1
    compare exp err || fail=1

    # Ensure that s1 is still present.
    test -e s1 || fail=1

    # Without --backup, ensure there is no backup file.
    test -e s2~ && fail=1
  fi

done

Exit $fail
