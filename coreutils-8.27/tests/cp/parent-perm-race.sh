#!/bin/sh
# Make sure cp -pR --parents isn't too generous with parent permissions.

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

umask 002
mkdir mode ownership d || framework_failure_
chmod g+s d 2>/dev/null # The cp test is valid either way.

# Terminate any background cp process.
pid=
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

for attr in mode ownership
do
  mkfifo_or_skip_ $attr/fifo

  # Copy a fifo's contents.  That way, we can examine d/$attr's
  # state while cp is running.
  timeout 10 cp --preserve=$attr -R --copy-contents --parents $attr d & pid=$!

  # Check the permissions of the destination directory that 'cp' has made.
  # 'ls' won't start until after 'cp' has made the destination directory
  # $d/attr and has started to read the source file $attr/fifo.
  timeout 10 sh -c "ls -ld d/$attr >$attr/fifo" || fail=1

  wait $pid || fail=1

  ls_output=$(cat d/$attr/fifo) || fail=1
  case $attr,$ls_output in
  ownership,d???--[-S]--[-S]* | \
  mode,d????-??-?* | \
  mode,d??[-x]?w[-x]?-[-x]* )
    ;;
  *)
    fail=1;;
  esac
done

Exit $fail
