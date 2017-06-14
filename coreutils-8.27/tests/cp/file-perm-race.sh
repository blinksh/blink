#!/bin/sh
# Make sure cp -p isn't too generous with file permissions.

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
print_ver_ cp

# cp -p gives ENOTSUP on NFS on Linux 2.6.9 at least
require_local_dir_

umask 022
mkfifo_or_skip_ fifo

# Terminate any background cp process
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

# Copy a fifo's contents.  That way, we can examine the
# destination permissions before they're finalized.
cp -p --copy-contents fifo fifo-copy & pid=$!

(
  # Now 'cp' is reading the fifo.  Wait for the destination file to
  # be created, encouraging things along by echoing to the fifo.
  while test ! -f fifo-copy; do
    echo foo
  done

  # Check the permissions of the destination.
  ls -l fifo-copy >ls.out

  # Close the fifo so that "cp" can continue.  But output first,
  # before exiting, otherwise some shells would optimize away the file
  # descriptor that holds the fifo open.
  echo foo
) >fifo

case $(cat ls.out) in
-???------*) ;;
*) fail=1;;
esac

wait $pid || fail=1

Exit $fail
