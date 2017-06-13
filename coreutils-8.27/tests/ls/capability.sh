#!/bin/sh
# Ensure "ls --color" properly colorizes file with capability.

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
print_ver_ ls printf
require_root_

grep '^#define HAVE_CAP 1' $CONFIG_HEADER > /dev/null \
  || skip_ "configured without libcap support"

(setcap --help) 2>&1 |grep 'usage: setcap' > /dev/null \
  || skip_ "setcap utility not found"

# Don't let a different umask perturb the results.
umask 22

# We create 2 files of the same name as
# before coreutils 8.1 only the name rather than
# the full path was used to read the capabilities
# thus giving false positives and negatives.
mkdir test test/dir
cd test
touch cap_pos dir/cap_pos dir/cap_neg
for file in cap_pos dir/cap_neg; do
  setcap 'cap_net_bind_service=ep' $file ||
    skip_ "setcap doesn't work"
done

code='30;41'
# Note we explicitly disable "executable" coloring
# so that capability coloring is not dependent on it,
# as was the case before coreutils 8.1
for ex in '' ex=:; do
  LS_COLORS="di=:${ex}ca=$code" \
    ls --color=always cap_pos dir > out || fail=1

  env printf "\
\e[0m\e[${code}mcap_pos\e[0m

dir:
\e[${code}mcap_neg\e[0m
cap_pos
" > out_ok || framework_failure_

  compare out out_ok || fail=1
done

Exit $fail
