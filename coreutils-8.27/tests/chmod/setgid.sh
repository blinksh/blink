#!/bin/sh
# Make sure GNU chmod works the same way as those of Solaris, HPUX, AIX
# on directories with the setgid bit set.  Also, check that the GNU octal
# notations work.

# Copyright (C) 2001-2017 Free Software Foundation, Inc.

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
print_ver_ chmod

umask 0
mkdir -m 755 d || framework_failure_

chmod g+s d 2> /dev/null && env -- test -g d ||
  {
    # This is required because on some systems (at least NetBSD 1.4.2A),
    # it may happen that when you create a directory, its group isn't one
    # to which you belong.  When that happens, the above chmod fails.  So
    # here, upon failure, we try to set the group, then rerun the chmod command.

    id_g=$(id -g) &&
    test -n "$id_g" &&
    chgrp "$id_g" d &&
    chmod g+s d || framework_failure_
  }

# "chmod g+s d" does nothing on some NFS file systems.
env -- test -g d ||
  skip_ 'cannot create setgid directories'

for mode in \
  + - g-s 00755 000755 =755 -2000 -7022 755 0755 \
  +2000 -5022 =7777,-5022
do
  chmod $mode d || fail=1

  case $mode in
    g-s | 00*755 | =755 | -2000 | -7022)
       expected_mode=drwxr-xr-x ;;
    *) expected_mode=drwxr-sr-x ;;
  esac
  ls_output=$(ls -ld d)
  case $ls_output in
    $expected_mode*) ;;
    *) fail=1 ;;
  esac

  chmod =2755 d || fail=1
done

Exit $fail
