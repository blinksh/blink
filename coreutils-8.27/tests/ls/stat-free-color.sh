#!/bin/sh
# Show that --color need not use stat, as long as we have d_type support.

# Copyright (C) 2011-2017 Free Software Foundation, Inc.

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
print_ver_ ls

# Note this list of _file name_ stat functions must be
# as cross platform as possible and so doesn't include
# fstatat64 as that's not available on aarch64 for example.
stats='stat,lstat,stat64,lstat64,newfstatat'

require_strace_ $stats
require_dirent_d_type_

# Disable enough features via LS_COLORS so that ls --color
# can do its job without calling stat (other than the obligatory
# one-call-per-command-line argument).
cat <<EOF > color-without-stat || framework_failure_
RESET 0
DIR 01;34
LINK 01;36
FIFO 40;33
SOCK 01;35
DOOR 01;35
BLK 40;33;01
CHR 40;33;01
ORPHAN 00
SETUID 00
SETGID 00
CAPABILITY 00
STICKY_OTHER_WRITABLE 00
OTHER_WRITABLE 00
STICKY 00
EXEC 00
MULTIHARDLINK 00
EOF
eval $(dircolors -b color-without-stat)

# The system may perform additional stat-like calls before main.
# Furthermore, underlying library functions may also implicitly
# add an extra stat call, e.g. opendir since glibc-2.21-360-g46f894d.
# To avoid counting those, first get a baseline count for running
# ls with one empty directory argument.  Then, compare that with the
# invocation under test.
mkdir d || framework_failure_

strace -o log1 -e $stats ls --color=always d || fail=1
n_stat1=$(wc -l < log1) || framework_failure_

test $n_stat1 = 0 \
  && skip_ 'No stat calls recognized on this platform'

# Populate the test directory.
mkdir d/subdir \
  && touch d/regf \
  && ln d/regf d/hlink \
  && ln -s regf d/slink \
  && ln -s nowhere d/dangle \
  || framework_failure_

# Invocation under test.
strace -o log2 -e $stats ls --color=always d || fail=1
n_stat2=$(wc -l < log2) || framework_failure_

# Expect the same number of stat calls.
test $n_stat1 = $n_stat2 \
  || { fail=1; head -n30 log*; }

Exit $fail
