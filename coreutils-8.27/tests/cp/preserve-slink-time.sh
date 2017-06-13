#!/bin/sh
# Verify that cp -Pp preserves times even on symlinks.

# Copyright (C) 2009-2017 Free Software Foundation, Inc.

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

grep '^#define HAVE_UTIMENSAT 1' "$CONFIG_HEADER" > /dev/null ||
grep '^#define HAVE_LUTIMES 1' "$CONFIG_HEADER" > /dev/null ||
  skip_ 'this system lacks the utimensat function'

ln -s no-such dangle || framework_failure_

# If the current file system lacks sub-second resolution, sleep for 2s to
# ensure that the times on the copy are different from those of the original.
case $(stat --format=%y dangle) in
  ??:??:??.000000000) sleep 2;;
esac

copy_timestamp_() {
  sleep $1
  rm -f d2
  cp -Pp dangle d2 || framework_failure_
  # Can't use --format=%x, as lstat() modifies atime on some platforms.
  stat --format=%y dangle > t1 || framework_failure_
  stat --format=%y d2 > t2 || framework_failure_
  compare t1 t2
}

# We retry with a delay at least 1.5s because on GPFS
# it was seen that the timestamp wasn't updated unless there
# was sufficient delay between the ln and cp.
# I.e., if there wasn't sufficient difference in
# the timestamp being updated, the update was discarded.
retry_delay_ copy_timestamp_ .1 4 || fail=1

Exit $fail
