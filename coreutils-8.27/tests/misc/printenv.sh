#!/bin/sh
# Verify behavior of printenv.

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
print_ver_ printenv

# Without arguments, printenv behaves like env.  Some shells provide
# printenv as a builtin, so we must invoke it via "env".
# But beware of $_, set by many shells to the last command run.
# Also, filter out LD_PRELOAD, which is set when running under valgrind.
# Note the apparently redundant "env  env": this is to ensure to get
# env's output the same way as that of printenv and works around a bug
# on aarch64 at least where libc's execvp reverses the order of the
# output.
env -- env | grep -Ev '^(_|LD_PRELOAD)=' > exp || framework_failure_
env -- printenv | grep -Ev '^(_|LD_PRELOAD)=' > out || fail=1
compare exp out || fail=1

# POSIX is clear that environ may, but need not be, sorted.
# Environment variable values may contain newlines, which cannot be
# observed by merely inspecting output from printenv.
if env -- printenv | grep '^ENV_TEST' >/dev/null ; then
  skip_ "environment has potential interference from ENV_TEST*"
fi

# Printing a single variable's value.
returns_ 1 env -- printenv ENV_TEST > out || fail=1
compare /dev/null out || fail=1
echo a > exp || framework_failure_
ENV_TEST=a env -- printenv ENV_TEST > out || fail=1
compare exp out || fail=1

# Printing multiple variables.  Order follows command line.
ENV_TEST1=a ENV_TEST2=b env -- printenv ENV_TEST2 ENV_TEST1 ENV_TEST2 > out \
  || fail=1
ENV_TEST1=a ENV_TEST2=b env -- printenv ENV_TEST1 ENV_TEST2 >> out || fail=1
cat <<EOF > exp || framework_failure_
b
a
b
a
b
EOF
compare exp out || fail=1

# Exit status reflects missing variable, but remaining arguments processed.
export ENV_TEST1=a
returns_ 1 env -- printenv ENV_TEST2 ENV_TEST1 > out || fail=1
returns_ 1 env -- printenv ENV_TEST1 ENV_TEST2 >> out || fail=1
unset ENV_TEST1
cat <<EOF > exp || framework_failure_
a
a
EOF
compare exp out || fail=1

# Non-standard environment variable name.  Shells won't create it, but
# env can, and printenv must be able to deal with it.
echo b > exp || framework_failure_
env -- -a=b printenv -- -a > out || fail=1
compare exp out || fail=1

# Silently reject invalid env-var names.
# Bug present through coreutils 8.0.
returns_ 1 env a=b=c printenv a=b > out || fail=1
compare /dev/null out || fail=1

Exit $fail
