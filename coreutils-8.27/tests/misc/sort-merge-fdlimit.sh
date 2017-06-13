#!/bin/sh
# Test whether sort avoids opening more file descriptors than it is
# allowed when merging files.

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
print_ver_ sort

mkdir in err || framework_failure_


for i in $(seq 17); do
  echo $i >in/$i
done
seq 17 >some-data

# When these tests are run inside the automated testing framework, they
# have one less available file descriptor than when run outside the
# automated testing framework. If a test with a batch size of b fails
# inside the ATF, then the same test with batch size b+1 may pass outside
# the ATF but fail inside it.

# The default batch size (nmerge) is 16.
(ulimit -n 19 \
   && sort -m --batch-size=16 in/* 2>err/merge-default-err \
   || ! grep "open failed" err/merge-default-err) || fail=1

# If sort opens a file to sort by random hashes of keys,
# it needs to consider this file against its limit on open file
# descriptors.  Test once with the default random source
# and once with an explicit source.
for randsource in '' --random-source=some-data; do
  (ulimit -n 20 \
     && sort -mR $randsource --batch-size=16 in/* 2>err/merge-random-err \
     || ! grep "open failed" err/merge-random-err) || fail=1
done

# 'sort -m' should work in a limited file descriptor
# environment when the output is repeatedly one of its inputs.
# In coreutils 8.7 and earlier, 'sort' would dump core on this test.
#
# This test uses 'exec' to redirect file descriptors rather than
# ordinary redirection on the 'sort' command.  This is intended to
# work around bugs in OpenBSD /bin/sh, and some other sh variants,
# that squirrel away file descriptors before closing them; see
# <https://lists.gnu.org/archive/html/bug-tar/2010-10/msg00075.html>.
# This test finds the bug only with shells that do not close FDs on
# exec, and will miss the bug (if present) on other shells, but it's
# not easy to fix this without running afoul of the OpenBSD-like sh bugs.
(seq 6 && echo 6) >exp || fail=1
echo 6 >out || fail=1
(exec 3<&- 4<&- 5<&- 6</dev/null 7<&6 8<&6 9<&6 &&
 ulimit -n 10 &&
 sort -n -m --batch-size=7 -o out out in/1 in/2 in/3 in/4 in/5 out
) &&
compare exp out || fail=1

Exit $fail
