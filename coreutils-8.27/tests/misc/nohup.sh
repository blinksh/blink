#!/bin/sh
# test nohup

# Copyright (C) 2003-2017 Free Software Foundation, Inc.

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
print_ver_ nohup


nohup sh -c 'echo stdout; echo stderr 1>&2' 2>err || fail=1

# Be careful.  The results of the above nohup command
# change depending on whether stdin and stdout are redirected.
if test -t 1; then
  test "$(cat nohup.out)" = stdout || fail=1
  if test -t 0; then
    echo 'nohup: ignoring input and appending output to 'nohup.out'\'
  else
    echo 'nohup: appending output to 'nohup.out'\'
  fi >exp || fail=1
else
  # Here it should not even exist.
  test -f nohup.out && fail=1
  if test -t 0; then
    echo 'nohup: ignoring input' >exp
  else
    rm -f exp
  fi || fail=1
fi
echo 'stderr' >> exp || fail=1

compare exp err || fail=1
rm -f nohup.out err exp
# ----------------------

# Be careful.  The results of the following nohup command
# change depending on whether stderr is redirected.
nohup sh -c 'echo stdout; echo stderr 1>&2' >out || fail=1
if test -t 2; then
  test "$(cat out|tr '\n' -)" = stdout-stderr- || fail=1
else
  test "$(cat out|tr '\n' -)" = stdout- || fail=1
fi
# It must *not* exist.
test -f nohup.out && fail=1
rm -f nohup.out err
# ----------------------

# Bug present through coreutils 8.0: failure to print advisory message
# to stderr must be fatal.  Requires stdout to be terminal.
if test -w /dev/full && test -c /dev/full; then
(
  # POSIX shells immediately exit the subshell on exec error.
  # So check we can write to /dev/tty before the exec, which
  # isn't possible if we've no controlling tty for example.
  test -c /dev/tty && >/dev/tty || exit 0

  exec >/dev/tty
  test -t 1 || exit 0
  returns_ 125 nohup echo hi 2> /dev/full || fail=1
  test -f nohup.out || fail=1
  compare /dev/null nohup.out || fail=1
  rm -f nohup.out
  exit $fail
) || fail=1
fi

nohup no-such-command 2> err
errno=$?
if test -t 1; then
  test $errno = 127 || fail=1
  # It must exist.
  test -f nohup.out || fail=1
  # It must be empty.
  compare /dev/null nohup.out || fail=1
fi

cat <<\EOF > exp || fail=1
nohup: appending output to 'nohup.out'
nohup: cannot run command 'no-such-command': No such file or directory
EOF
# Disable these comparisons.  Too much variation in 2nd line.
# compare exp err || fail=1
rm -f nohup.out err exp
# ----------------------

touch k; chmod 0 k
nohup ./k 2> err
errno=$?
test $errno = 126 || fail=1
if test -t 1; then
  # It must exist.
  test -f nohup.out || fail=1
  # It must be empty.
  compare /dev/null nohup.out || fail=1
fi

cat <<\EOF > exp || fail=1
nohup: appending output to 'nohup.out'
nohup: cannot run command './k': Permission denied
EOF
# Disable these comparisons.  Too much variation in 2nd line.
# compare exp err || fail=1

# Make sure it fails with exit status of 125 when given too few arguments,
# except that POSIX requires 127 in this case.
returns_ 125 nohup >/dev/null 2>&1 || fail=1
export POSIXLY_CORRECT=1
returns_ 127 nohup >/dev/null 2>&1 || fail=1
unset POSIXLY_CORRECT

Exit $fail
