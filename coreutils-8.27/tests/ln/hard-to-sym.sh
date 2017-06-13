#!/bin/sh
# Tests for ln -L/-P.

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
print_ver_ ln


# ===================================================
# ensure -s silently overrides -L, -P
touch a || framework_failure_
ln -L -s a symlink1 || fail=1
ln -P -s symlink1 symlink2 || fail=1
ln -s -L -P symlink2 symlink3 || fail=1

# ===================================================
# ensure that -L follows symlinks, and overrides -P
if ln -P -L symlink3 hard-to-a; then
  ls=$(ls -lG hard-to-a)x
  case "$ls" in
    *'hard-to-ax') ;;
    *'hard-to-a -> '*x) fail=1 ;;
    *) framework_failure_ ;;
  esac
else
  fail=1
fi

# ===================================================
# ensure that -P links (or at least duplicates) symlinks, and overrides -L
if ln -L -P symlink3 hard-to-3; then
  ls=$(ls -lG hard-to-3)x
  case "$ls" in
    *'hard-to-3 -> symlink2x') ;;
    *'hard-to-3x') fail=1 ;;
    *'hard-to-3 -> '*x) fail=1 ;;
    *) framework_failure_ ;;
  esac
else
  fail=1
fi

# ===================================================
# Create a hard link to a dangling symlink.
ln -s /no-such-dir || framework_failure_
ln -L no-such-dir hard-to-dangle 2>err && fail=1
case $(cat err) in
  *" failed to access 'no-such-dir'":*) ;;
  *) fail=1 ;;
esac
ln -P no-such-dir hard-to-dangle || fail=1

# ===================================================
# Create a hard link to a symlink to a directory.
mkdir d || framework_failure_
ln -s d link-to-dir || framework_failure_
ln -L link-to-dir hard-to-dir-link 2>err && fail=1
case $(cat err) in
  *": link-to-dir: hard link not allowed for directory"*) ;;
  *) fail=1 ;;
esac
ln -P link-to-dir/ hard-to-dir-link 2>err && fail=1
case $(cat err) in
  *": link-to-dir/: hard link not allowed for directory"*) ;;
  *) fail=1 ;;
esac
ln -P link-to-dir hard-to-dir-link || fail=1

Exit $fail
