#!/bin/sh
# Compare actual numbers from du, assuming block size matches mine.

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
print_ver_ du

mkdir -p a/b d d/sub || framework_failure_

# Ensure that these files contain more than 64 bytes, so that we don't
# immediately disqualify file systems (e.g., NetApp) on which smaller
# files take up zero disk blocks.
printf '%*s' 257 make-sure-the-file-is-non-empty > a/b/F || framework_failure_
printf %4096s x > d/1
cp d/1 d/sub/2


B=$(stat --format=%B a/b/F)

du --block-size=$B -a a > out || fail=1
echo === >> out
du --block-size=$B -a -S a >> out || fail=1
echo === >> out
du --block-size=$B -s a >> out || fail=1

f=$(stat --format=%b a/b/F)
b=$(stat --format=%b a/b)
a=$(stat --format=%b a)
bf=$(expr $b + $f)
tot=$(expr $bf + $a)

cat <<EOF | sed 's/ *#.*//' > exp
$f	a/b/F
$bf	a/b
$tot	a
===
$f	a/b/F   # size of file, a/b/F
$bf	a/b     # size of dir entry, a/b, + size of file, a/b/F
$a	a       # size of dir entry, a
===
$tot	a
EOF

compare exp out || fail=1

# Perform this test only if "." is on a local file system.
# Otherwise, it would fail e.g., on an NFS-mounted Solaris ZFS file system.
if is_local_dir_ .; then
  rm -f out exp
  du --block-size=$B -a d | sort -r -k2,2 > out || fail=1
  echo === >> out
  du --block-size=$B -S d | sort -r -k2,2 >> out || fail=1

  t2=$(stat --format=%b d/sub/2)
  ts=$(stat --format=%b d/sub)
  t1=$(stat --format=%b d/1)
  td=$(stat --format=%b d)
  tot=$(expr $t1 + $t2 + $ts + $td)
  d1=$(expr $td + $t1)
  s2=$(expr $ts + $t2)

  cat <<EOF | sed 's/ *#.*//' > exp
$t2	d/sub/2
$s2	d/sub
$t1	d/1
$tot	d
===
$s2	d/sub
$d1	d           # d + d/1; don't count the dir. entry for d/sub
EOF

  compare exp out || fail=1
fi

Exit $fail
