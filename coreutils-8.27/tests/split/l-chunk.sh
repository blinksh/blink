#!/bin/sh
# test splitting into newline delineated chunks (-n l/...)

# Copyright (C) 2010-2017 Free Software Foundation, Inc.

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

# invalid number of chunks
echo "split: invalid number of chunks: '1o'" > exp
returns_ 1 split -n l/1o 2>err || fail=1
compare exp err || fail=1

echo "split: -: cannot determine file size" > exp
: | returns_ 1 split -n l/1 2>err || fail=1
compare exp err || fail=1

# N can be greater than the file size
# in which case no data is extracted, or empty files are written
split -n l/10 /dev/null || fail=1
test "$(stat -c %s x* | uniq -c | sed 's/^ *//; s/ /x/')" = "10x0" || fail=1
rm x??

# 'split' should reject any attempt to create an infinitely
# long output file.
returns_ 1 split -n l/2 /dev/zero || fail=1
rm x??

# Repeat the above,  but with 1/2, not l/2:
returns_ 1 split -n 1/2 /dev/zero || fail=1
rm x??

# Ensure --elide-empty-files is honored
split -e -n l/10 /dev/null || fail=1
returns_ 1 stat x?? 2>/dev/null || fail=1

# 80 bytes. ~ transformed to \n below
lines=\
12345~1~12345~1~12345~1~12345~1~12345~~~12345~1~12345~1~12345~1~12345~1~12345~1~

printf "%s" "$lines" | tr '~' '\n' > in || framework_failure_

echo "split: invalid chunk number: '16'" > exp
returns_ 1 split -n l/16/15 in 2>err.t || fail=1
sed "s/': .*/'/" < err.t > err || framework_failure_
compare exp err || fail=1

printf '%s' "\
14 16 09 15 16 10
14 08 08 10 14 08 08 10
06 08 08 02 06 08 08 02 06 08 08 10
06 08 02 06 08 00 08 02 06 08 02 06 08 00 10
06 00 08 00 02 06 00 02 06 00 08 00 01 07 00 02 06 00 08 00 02 16
" > exp || framework_failure_

sed 's/00 *//g' exp > exp.elide_empty || framework_failure_

DEBUGGING=
test "$DEBUGGING" && test "$VERBOSE" && set +x
for ELIDE_EMPTY in '' '-e'; do
  for IO_BLKSIZE in 1 2 5 10 80 100; do
    > out
    test "$DEBUGGING" && printf "\n---io-blk-size=$IO_BLKSIZE $ELIDE_EMPTY\n"
    for N in 6 8 12 15 22; do
      rm -f x*

      if test -z "$ELIDE_EMPTY"; then
        split ---io-blksize=$IO_BLKSIZE -n l/2/$N in > chunk.k
        returns_ 1 stat x* 2>/dev/null || fail=1
      fi

      split ---io-blksize=$IO_BLKSIZE $ELIDE_EMPTY -n l/$N in
      echo $(stat -c "%02s" x*) >> out

      if test -z "$ELIDE_EMPTY"; then
        compare chunk.k xab || fail=1
      fi

      if test "$DEBUGGING"; then
        # Output partition pattern
        size=$(printf "%s" "$lines" | wc -c)
        chunk_size=$(($size/$N))
        end_size=$(($chunk_size + ($size % $N)))
        {
          yes "$(printf %${chunk_size}s ])" | head -n$(($N-1))
          printf %${end_size}s ]
        } | tr -d '\n' | sed "s/\\(^.\\{1,$size\\}\\).*/\\1/"
        echo

        # Output pattern generated for comparison
        for s in $(stat -c "%s" x*); do
          #s=0 transitions are not shown
          test "$m" = "_" && m=- || m=_
          printf "%${s}s" '' | tr ' ' $m
        done
        echo

        # Output lines for reference
        echo "$lines"
      fi
    done
    test -z "$ELIDE_EMPTY" && EXP=exp || EXP=exp.elide_empty
    compare out $EXP || fail=1
  done
done
test "$DEBUGGING" && test "$VERBOSE" && set -x


# Check extraction of particular chunks
> out
printf '1\n12345\n' > exp
split -n l/13/15 in > out
compare exp out || fail=1
> out
printf '' > exp
split -n l/14/15 in > out
compare exp out || fail=1
> out
printf '1\n12345\n1\n' > exp
split -n l/15/15 in > out
compare exp out || fail=1

# test input with no \n at end
printf '12\n34\n5' > in
printf '5' > exp
split -n l/7/7 in > out
compare exp out || fail=1

Exit $fail
