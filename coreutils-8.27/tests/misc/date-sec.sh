#!/bin/sh
# Ensure that a command like
# date --date="21:04 +0100" +%S' always prints '00'.
# Before coreutils-5.2.1, it would print the seconds from the current time.

# Copyright (C) 2004-2017 Free Software Foundation, Inc.

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
print_ver_ date



# It would be easier simply to sleep for two seconds between two runs
# of $(date --date="21:04 +0100" +%S) and ensure that both outputs
# are '00', but I prefer not to sleep unconditionally.  'make check'
# takes long enough as it is.

n=0
# See if the current number of seconds is '00' or just before.
s=$(date +%S)
case "$s" in
  58) n=3;;
  59) n=2;;
  00) n=1;;
esac

# If necessary, wait for the system clock to pass the minute mark.
test $n = 0 || sleep $n

s=$(date --date="21:04 +0100" +%S)
case "$s" in
  00) ;;
  *) fail=1;;
esac

Exit $fail
