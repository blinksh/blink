#!/bin/sh
# Exercise ls --block-size and related options.

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

TZ=UTC0
export TZ

mkdir sub
cd sub

for size in 1024 4096 262144; do
  echo foo | dd conv=sync bs=$size >file$size || fail=1
done
touch -d '2001-01-01 00:00' file* || fail=1

size_etc='s/[^ ]* *[^ ]* *//'

ls -og * | sed "$size_etc" >../out || fail=1
POSIXLY_CORRECT=1 ls -og * | sed "$size_etc" >>../out || fail=1
POSIXLY_CORRECT=1 ls -k -og * | sed "$size_etc" >>../out || fail=1

for var in BLOCKSIZE BLOCK_SIZE LS_BLOCK_SIZE; do
  for blocksize in 1 512 1K 1KiB; do
    (eval $var=$blocksize && export $var &&
     ls -og * &&
     ls -og -k * &&
     ls -og -k --block-size=$blocksize *
    ) | sed "$size_etc" >>../out || fail=1
  done
done

cd ..

cat >exp <<'EOF'
1024 Jan  1  2001 file1024
262144 Jan  1  2001 file262144
4096 Jan  1  2001 file4096
1024 Jan  1  2001 file1024
262144 Jan  1  2001 file262144
4096 Jan  1  2001 file4096
1024 Jan  1  2001 file1024
262144 Jan  1  2001 file262144
4096 Jan  1  2001 file4096
1024 Jan  1  2001 file1024
262144 Jan  1  2001 file262144
4096 Jan  1  2001 file4096
1024 Jan  1  2001 file1024
262144 Jan  1  2001 file262144
4096 Jan  1  2001 file4096
1024 Jan  1  2001 file1024
262144 Jan  1  2001 file262144
4096 Jan  1  2001 file4096
1024 Jan  1  2001 file1024
262144 Jan  1  2001 file262144
4096 Jan  1  2001 file4096
1024 Jan  1  2001 file1024
262144 Jan  1  2001 file262144
4096 Jan  1  2001 file4096
2 Jan  1  2001 file1024
512 Jan  1  2001 file262144
8 Jan  1  2001 file4096
1024 Jan  1  2001 file1024
262144 Jan  1  2001 file262144
4096 Jan  1  2001 file4096
1024 Jan  1  2001 file1024
262144 Jan  1  2001 file262144
4096 Jan  1  2001 file4096
1 Jan  1  2001 file1024
256 Jan  1  2001 file262144
4 Jan  1  2001 file4096
1024 Jan  1  2001 file1024
262144 Jan  1  2001 file262144
4096 Jan  1  2001 file4096
1024 Jan  1  2001 file1024
262144 Jan  1  2001 file262144
4096 Jan  1  2001 file4096
1 Jan  1  2001 file1024
256 Jan  1  2001 file262144
4 Jan  1  2001 file4096
1024 Jan  1  2001 file1024
262144 Jan  1  2001 file262144
4096 Jan  1  2001 file4096
1024 Jan  1  2001 file1024
262144 Jan  1  2001 file262144
4096 Jan  1  2001 file4096
1024 Jan  1  2001 file1024
262144 Jan  1  2001 file262144
4096 Jan  1  2001 file4096
2 Jan  1  2001 file1024
512 Jan  1  2001 file262144
8 Jan  1  2001 file4096
2 Jan  1  2001 file1024
512 Jan  1  2001 file262144
8 Jan  1  2001 file4096
2 Jan  1  2001 file1024
512 Jan  1  2001 file262144
8 Jan  1  2001 file4096
1 Jan  1  2001 file1024
256 Jan  1  2001 file262144
4 Jan  1  2001 file4096
1 Jan  1  2001 file1024
256 Jan  1  2001 file262144
4 Jan  1  2001 file4096
1 Jan  1  2001 file1024
256 Jan  1  2001 file262144
4 Jan  1  2001 file4096
1 Jan  1  2001 file1024
256 Jan  1  2001 file262144
4 Jan  1  2001 file4096
1 Jan  1  2001 file1024
256 Jan  1  2001 file262144
4 Jan  1  2001 file4096
1 Jan  1  2001 file1024
256 Jan  1  2001 file262144
4 Jan  1  2001 file4096
1024 Jan  1  2001 file1024
262144 Jan  1  2001 file262144
4096 Jan  1  2001 file4096
1024 Jan  1  2001 file1024
262144 Jan  1  2001 file262144
4096 Jan  1  2001 file4096
1024 Jan  1  2001 file1024
262144 Jan  1  2001 file262144
4096 Jan  1  2001 file4096
2 Jan  1  2001 file1024
512 Jan  1  2001 file262144
8 Jan  1  2001 file4096
2 Jan  1  2001 file1024
512 Jan  1  2001 file262144
8 Jan  1  2001 file4096
2 Jan  1  2001 file1024
512 Jan  1  2001 file262144
8 Jan  1  2001 file4096
1 Jan  1  2001 file1024
256 Jan  1  2001 file262144
4 Jan  1  2001 file4096
1 Jan  1  2001 file1024
256 Jan  1  2001 file262144
4 Jan  1  2001 file4096
1 Jan  1  2001 file1024
256 Jan  1  2001 file262144
4 Jan  1  2001 file4096
1 Jan  1  2001 file1024
256 Jan  1  2001 file262144
4 Jan  1  2001 file4096
1 Jan  1  2001 file1024
256 Jan  1  2001 file262144
4 Jan  1  2001 file4096
1 Jan  1  2001 file1024
256 Jan  1  2001 file262144
4 Jan  1  2001 file4096
EOF

compare exp out || fail=1

Exit $fail
