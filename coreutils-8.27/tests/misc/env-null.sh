#!/bin/sh
# Verify behavior of env -0 and printenv -0.

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
print_ver_ env printenv

# POSIX is clear that environ may, but need not be, sorted.
# Environment variable values may contain newlines, which cannot be
# observed by merely inspecting output from env.
# Cygwin requires a minimal environment to launch new processes: execve
# adds missing variables SYSTEMROOT and WINDIR, which show up in a
# subsequent env.  Cygwin also requires /bin to always be part of PATH,
# and attempts to unset or reduce PATH may cause execve to fail.
#
# For these reasons, it is better to compare two outputs from distinct
# programs that should be the same, rather than building an exp file.
env -i PATH="$PATH" env -0 > out1 || fail=1
env -i PATH="$PATH" printenv -0 > out2 || fail=1
compare out1 out2 || fail=1
env -i PATH="$PATH" env --null > out2 || fail=1
compare out1 out2 || fail=1
env -i PATH="$PATH" printenv --null > out2 || fail=1
compare out1 out2 || fail=1

# env -0 does not work if a command is specified.
returns_ 125 env -0 echo hi > out || fail=1
compare /dev/null out || fail=1

# Test env -0 on a one-variable environment.
printf 'a=b\nc=\0' > exp || framework_failure_
env -i -0 "$(printf 'a=b\nc=')" > out || fail=1
compare exp out || fail=1

# Test printenv -0 on particular values.
printf 'b\nc=\0' > exp || framework_failure_
env "$(printf 'a=b\nc=')" printenv -0 a > out || fail=1
compare exp out || fail=1
returns_ 1 env -u a printenv -0 a > out || fail=1
compare /dev/null out || fail=1
returns_ 1 env -u b "$(printf 'a=b\nc=')" printenv -0 b a > out || fail=1
compare exp out || fail=1

Exit $fail
