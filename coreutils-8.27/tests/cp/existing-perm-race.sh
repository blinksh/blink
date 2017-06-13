#!/bin/sh
# Make sure cp -p isn't too generous with existing file permissions.

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

require_membership_in_two_groups_

# cp -p gives ENOTSUP on NFS on Linux 2.6.9 at least
require_local_dir_

require_no_default_acl_ .

set _ $groups; shift
g1=$1
g2=$2


umask 077
mkfifo_or_skip_ fifo

touch fifo-copy &&
chgrp $g1 fifo &&
chgrp $g2 fifo-copy &&
chmod g+r fifo-copy || framework-failure

# Terminate any background cp process
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

# Copy a fifo's contents.  That way, we can examine the
# destination permissions before they're finalized.
cp -p --copy-contents fifo fifo-copy & pid=$!

(
  # Now 'cp' is reading the fifo.  Wait for the destination file to
  # be written to, encouraging things along by echoing to the fifo.
  while test ! -s fifo-copy; do
    echo foo
  done

  # Check the permissions of the destination.
  ls -l -n fifo-copy >ls.out &&

  # Close the fifo so that "cp" can continue.  But output first,
  # before exiting, otherwise some shells would optimize away the file
  # descriptor that holds the fifo open.
  echo foo
) >fifo || fail=1

# Check that the destination mode is safe while the file is being copied.
read mode links owner group etc <ls.out || fail=1
case $mode in
  -rw-------*) ;;

  # FIXME: Remove the following case; the file mode should always be
  # 600 while the data are being copied.  This will require changing
  # cp so that it also does not put $g1's data in a file that is
  # accessible to $g2.  This fix will not close a security hole, since
  # a $g2 process can maintain an open file descriptor to the
  # destination, but it's safer anyway.
  -rw-r-----*)
    # If the file has group $g1 and is group-readable, that is definitely bogus,
    # as neither the source nor the destination was readable to group $g1.
    test "$group" = "$g1" && fail=1;;

  *) fail=1;;
esac

wait $pid || fail=1

# Check that the final mode and group are right.
ls -l -n fifo-copy >ls.out &&
read mode links owner group etc <ls.out || fail=1
case $mode in
  -rw-------*) test "$group" = "$g1" || fail=1;;
  *) fail=1;;
esac

Exit $fail
