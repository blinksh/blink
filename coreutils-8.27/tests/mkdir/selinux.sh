#!/bin/sh
# ensure that an invalid context doesn't cause a segfault

# Copyright (C) 2008-2017 Free Software Foundation, Inc.

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
print_ver_ mkdir mkfifo mknod

# Note: on an SELinux/enforcing system running mcstransd older than
# mcstrans-0.2.8-1.fc9, the following commands may mistakenly exit
# successfully, in spite of the invalid context string.
require_selinux_enforcing_

c=invalid-selinux-context
msg="failed to set default file creation context to '$c':"

# Test each of mkdir, mknod, mkfifo with "-Z invalid-context".

for cmd_w_arg in 'mkdir dir' 'mknod b p' 'mkfifo f'; do
  # In OpenBSD's /bin/sh, mknod is a shell built-in.
  # Running via "env" ensures we run our program and not the built-in.
  env -- $cmd_w_arg --context=$c 2> out && fail=1
  set $cmd_w_arg; cmd=$1
  echo "$cmd: $msg" > exp || fail=1

  # Some systems fail with ENOTSUP, EINVAL, ENOENT, or even
  # "Unknown system error", or "Function not implemented".
  # For AIX 5.3: "Unsupported attribute value"
  # For HP-UX 11.23: Unknown error (252)
  sed					\
    -e 's/ Not supported$//'		\
    -e 's/ Invalid argument$//'		\
    -e 's/ Unknown system error$//'	\
    -e 's/ Operation not supported$//'	\
    -e 's/ Function not implemented$//'	\
    -e 's/ Unsupported attribute value$//'	\
    -e 's/ Unknown error .*$//'	\
    -e 's/ No such file or directory$//' out > k || fail=1
  mv k out || fail=1
  compare exp out || fail=1
done

Exit $fail
