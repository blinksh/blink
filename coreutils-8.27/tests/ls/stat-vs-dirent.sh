#!/bin/sh
# Ensure that d_ino (from ls -di) and st_ino (from stat --format=%i) match.

# Copyright (C) 2006-2017 Free Software Foundation, Inc.

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
print_ver_ ls


root_dev_ino=$(stat --format=%d-%i /)
t=$(pwd)
while :; do
  if ls -i1 "$t" > tmp; then
    # Extract the inode number from the first line of output from ls -i1.
    # This value comes from dirent.d_ino, on systems with d_ino support.
    d_ino=$(sed -n '1s/^ *\([0-9][0-9]*\) .*/\1/p;q' tmp)

    # Extract the name of the corresponding directory entry.
    file=$(sed -n '1s/^ *[0-9][0-9]* //p;q' tmp)

    # Get its inode number (stat.st_ino) via stat(1)'s call to lstat.
    st_ino=$(stat --format=%i "$t/$file")

    # Make sure that they are the same.
    # We know from experience that there may be mismatches on some
    # buggy file systems, at mount points.
    # Note that when a directory contains only entries whose names
    # start with ".", d_ino and file will both be empty.  In that case,
    # skip the test.
    if test -n "$d_ino" && test "$d_ino" != "$st_ino"; then
      echo "$0: test failed: $t/$file: d_ino($d_ino) != st_ino($st_ino)
        This may indicate a flaw in your kernel or file system implementation.
        The flaw isn't serious for coreutils, but it might break other tools,
        so you should report it to your operating system vendor." 1>&2

      fail=1
      break
    fi
  fi

  t=$(cd "$t/.."; pwd)
  dev_ino=$(stat --format=%d-%i "$t")
  test $dev_ino = $root_dev_ino && break
done

Exit $fail
