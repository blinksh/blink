#!/bin/sh
# Make sure touch can create a file through a dangling symlink.
# This was broken in the 4.0[e-i] test releases.

# Copyright (C) 1999-2017 Free Software Foundation, Inc.

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
print_ver_ touch

rm -f touch-target t-symlink
ln -s touch-target t-symlink

# This used to infloop.
touch t-symlink || fail=1

test -f touch-target || fail=1
rm -f touch-target t-symlink

if test $fail = 1; then
  case $host_triplet in
    *linux-gnu*)
      case "$(uname -r)" in
        2.3.9[0-9]*)
          skip_ \
'****************************************************
WARNING!!!
This version of the Linux kernel causes touch to fail
when operating on dangling symlinks.
****************************************************'
          ;;
      esac
      ;;
  esac
fi

Exit $fail
