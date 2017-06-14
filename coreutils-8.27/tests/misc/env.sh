#!/bin/sh
# Verify behavior of env.

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
print_ver_ env

# A simple shebang program to call "echo" from symlinks like "./-u" or "./--".
echo "#!$abs_top_builddir/src/echo simple_echo" > simple_echo \
  || framework_failure_
chmod a+x simple_echo || framework_failure_

# Verify we can run the shebang which is not the case if
# there are spaces in $abs_top_builddir.
./simple_echo || skip_ "Error running simple_echo script"

# Verify clearing the environment
a=1
export a
env - > out || fail=1
compare /dev/null out || fail=1
env -i > out || fail=1
compare /dev/null out || fail=1
env -u a -i -u a -- > out || fail=1
compare /dev/null out || fail=1
env -i -- a=b > out || fail=1
echo a=b > exp || framework_failure_
compare exp out || fail=1

# These tests verify exact status of internal failure.
returns_ 125 env --- || fail=1 # unknown option
returns_ 125 env -u || fail=1 # missing option argument
returns_ 2 env sh -c 'exit 2' || fail=1 # exit status propagation
returns_ 126 env . || fail=1 # invalid command
returns_ 127 env no_such || fail=1 # no such command

# POSIX is clear that environ may, but need not be, sorted.
# Environment variable values may contain newlines, which cannot be
# observed by merely inspecting output from env.
# Cygwin requires a minimal environment to launch new processes: execve
# adds missing variables SYSTEMROOT and WINDIR, which show up in a
# subsequent env.  Cygwin also requires /bin to always be part of PATH,
# and attempts to unset or reduce PATH may cause execve to fail.
#
# For these reasons, it is more portable to grep that our desired changes
# took place, rather than comparing output of env over an entire environment.
if env | grep '^ENV_TEST' >/dev/null ; then
  skip_ "environment has potential interference from ENV_TEST*"
fi

ENV_TEST1=a
export ENV_TEST1
>out || framework_failure_
env ENV_TEST2= > all || fail=1
grep '^ENV_TEST' all | LC_ALL=C sort >> out || framework_failure_
env -u ENV_TEST1 ENV_TEST3=c > all || fail=1
grep '^ENV_TEST' all | LC_ALL=C sort >> out || framework_failure_
env ENV_TEST1=b > all || fail=1
grep '^ENV_TEST' all | LC_ALL=C sort >> out || framework_failure_
env ENV_TEST2= env > all || fail=1
grep '^ENV_TEST' all | LC_ALL=C sort >> out || framework_failure_
env -u ENV_TEST1 ENV_TEST3=c env > all || fail=1
grep '^ENV_TEST' all | LC_ALL=C sort >> out || framework_failure_
env ENV_TEST1=b env > all || fail=1
grep '^ENV_TEST' all | LC_ALL=C sort >> out || framework_failure_
cat <<EOF >exp || framework_failure_
ENV_TEST1=a
ENV_TEST2=
ENV_TEST3=c
ENV_TEST1=b
ENV_TEST1=a
ENV_TEST2=
ENV_TEST3=c
ENV_TEST1=b
EOF
compare exp out || fail=1

# PATH modifications affect exec.
mkdir unlikely_name || framework_failure_
cat <<EOF > unlikely_name/also_unlikely || framework_failure_
#!/bin/sh
echo pass
EOF
chmod +x unlikely_name/also_unlikely || framework_failure_
returns_ 127 env also_unlikely || fail=1
test x$(PATH=$PATH:unlikely_name env also_unlikely) = xpass || fail=1
test x$(env PATH="$PATH":unlikely_name also_unlikely) = xpass || fail=1

# Explicitly put . on the PATH for the rest of this test.
PATH=$PATH:
export PATH

# Use -- to end options (but not variable assignments).
# On some systems, execve("-i") invokes a shebang script ./-i on PATH as
# '/bin/sh -i', rather than '/bin/sh -- -i', which doesn't do what we want.
# Avoid the issue by using a shebang to 'echo' passing a second parameter
# before the '-i'. See the definition of simple_echo before.
# Test -u, rather than -i, to minimize PATH problems.
ln -s "simple_echo" ./-u || framework_failure_
case $(env -u echo echo good) in
  good) ;;
  *) fail=1 ;;
esac
case $(env -u echo -- echo good) in
  good) ;;
  *) fail=1 ;;
esac
case $(env -- -u pass) in
  *pass) ;;
  *) fail=1 ;;
esac

# After options have ended, the first argument not containing = is a program.
returns_ 127 env a=b -- true || fail=1
ln -s "simple_echo" ./-- || framework_failure_
case $(env a=b -- true || echo fail) in
  *true) ;;
  *) fail=1 ;;
esac

# No way to directly invoke program name containing =.
cat <<EOF >./c=d || framework_failure_
#!/bin/sh
echo pass
EOF
chmod +x c=d || framework_failure_
test "x$(env c=d echo fail)" = xfail || fail=1
test "x$(env -- c=d echo fail)" = xfail || fail=1
test "x$(env ./c=d echo fail)" = xfail || fail=1
test "x$(env sh -c 'exec "$@"' sh c=d echo fail)" = xpass || fail=1
test "x$(sh -c '\c=d echo fail')" = xpass && #dash 0.5.4 fails so check first
  { test "x$(env sh -c '\c=d echo fail')" = xpass || fail=1; }

# catch unsetenv failure, broken through coreutils 8.0
returns_ 125 env -u a=b true || fail=1
returns_ 125 env -u '' true || fail=1

Exit $fail
