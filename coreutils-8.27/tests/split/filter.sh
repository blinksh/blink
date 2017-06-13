#!/bin/sh
# Exercise split's new --filter option.

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
print_ver_ split
require_sparse_support_ # for 'truncate --size=$OFF_T_MAX'
eval $(getlimits) # for OFF_T limits
xz --version || skip_ "xz (better than gzip/bzip2) required"

for total_n_lines in 5 3000 20000; do
  seq $total_n_lines > in || framework_failure_
  for i in 2 51 598; do

    # Don't create too many files/processes.
    # Starting 10k (or even "only" 1500) processes would take a long time,
    # and would provide little added benefit.
    case $i:$total_n_lines in 2:5);; *) continue;; esac

    split -l$i --filter='xz -1 > $FILE.xz' in out- || fail=1
    xz -dc out-* > out || fail=1
    compare in out || fail=1
    rm -f out*
  done
  rm -f in
done

# Show how --elide-empty-files works with --filter:
# split does not run the command (and effectively elides the file)
# only when the output to that command would have been empty.
split -e -n 10 --filter='xz > $FILE.xz' /dev/null || fail=1
returns_ 1 stat x?? 2>/dev/null || fail=1

# Ensure this invalid combination is flagged
returns_ 1 split -n 1/2 --filter='true' /dev/null 2>&1 || fail=1

# Ensure SIGPIPEs sent by the children don't propagate back
# where they would result in a non zero exit from split.
yes | head -n200K | split -b1G --filter='head -c1 >/dev/null' || fail=1

# Do not use a size of OFF_T_MAX, since split.c applies a GNU/Hurd
# /dev/zero workaround for files of that size.  Use one less:
N=$(expr $OFF_T_MAX - 1)

# Ensure that "endless" input is ignored when all filters finish
timeout 10 sh -c 'yes | split --filter="head -c1 >/dev/null" -n r/1' || fail=1
if truncate -s$N zero.in; then
  timeout 10 sh -c 'split --filter="head -c1 >/dev/null" -n 1 zero.in' || fail=1
fi

Exit $fail
