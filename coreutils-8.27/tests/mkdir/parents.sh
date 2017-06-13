#!/bin/sh
# make sure mkdir's -p options works properly

# Copyright (C) 2000-2017 Free Software Foundation, Inc.

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
print_ver_ mkdir
skip_if_setgid_
require_no_default_acl_ .

mkdir -m 700 e-dir || framework_failure_


# Make sure 'mkdir -p existing-dir' succeeds
# and that 'mkdir existing-dir' fails.
mkdir -p e-dir || fail=1
returns_ 1 mkdir e-dir > /dev/null 2>&1 || fail=1

# Create an existing directory.
umask 077
mode_str=drwxr-x-wx
mode_arg=$(rwx_to_mode_ $mode_str)
mkdir -m $mode_arg a || fail=1

# this 'mkdir -p ...' shouldn't change perms of existing dir 'a'.
d_mode_str=drwx-w--wx
d_mode_arg=$(rwx_to_mode_ $d_mode_str)
mkdir -p -m $d_mode_arg a/b/c/d

# Make sure the permissions of 'a' haven't been changed.
p=$(ls -ld a|cut -b-10); case $p in $mode_str);; *) fail=1;; esac
# 'b's and 'c's should reflect the umask
p=$(ls -ld a/b|cut -b-10); case $p in drwx------);; *) fail=1;; esac
p=$(ls -ld a/b/c|cut -b-10); case $p in drwx------);; *) fail=1;; esac

# 'd's perms are determined by the -m argument.
p=$(ls -ld a/b/c/d|cut -b-10); case $p in $d_mode_str);; *) fail=1;; esac

Exit $fail
