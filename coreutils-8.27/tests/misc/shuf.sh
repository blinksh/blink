#!/bin/sh
# Ensure that shuf randomizes its input.

# Copyright (C) 2006-2017 Free Software Foundation, Inc.

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
print_ver_ shuf
getlimits_

seq 100 > in || framework_failure_

shuf in >out || fail=1

# Fail if the input is the same as the output.
# This is a probabilistic test :-)
# However, the odds of failure are very low: 1 in 100! (~ 1 in 10^158)
compare in out > /dev/null && { fail=1; echo "not random?" 1>&2; }

# Fail if the sorted output is not the same as the input.
sort -n out > out1
compare in out1 || { fail=1; echo "not a permutation" 1>&2; }

# Exercise shuf's -i option.
shuf -i 1-100 > out || fail=1
compare in out > /dev/null && { fail=1; echo "not random?" 1>&2; }
sort -n out > out1
compare in out1 || { fail=1; echo "not a permutation" 1>&2; }

# Exercise shuf's -e option.
t=$(shuf -e a b c d e | sort | fmt)
test "$t" = 'a b c d e' || { fail=1; echo "not a permutation" 1>&2; }

# coreutils-8.22 dumps core.
shuf -er
test $? -eq 1 || fail=1

# coreutils-8.22 and 8.23 dump core
# with a single redundant operand with --input-range
shuf -i0-0 1
test $? -eq 1 || fail=1

# Before coreutils-6.3, this would infloop.
# "seq 1860" produces 8193 (8K + 1) bytes of output.
seq 1860 | shuf > /dev/null || fail=1

# coreutils-6.12 and earlier would output a newline terminator, not \0.
shuf --zero-terminated -i 1-1 > out || fail=1
printf '1\0' > exp || framework_failure_
cmp out exp || { fail=1; echo "missing NUL terminator?" 1>&2; }

# Ensure shuf -n operates efficiently for small n. Before coreutils-8.13
# this would try to allocate $SIZE_MAX * sizeof(size_t)
timeout 10 shuf -i1-$SIZE_MAX -n2 >/dev/null ||
  { fail=1; echo "couldn't get a small subset" >&2; }

# Ensure shuf -n0 doesn't read any input or open specified files
touch unreadable || framework_failure_
chmod 0 unreadable || framework_failure_
if ! test -r unreadable; then
  shuf -n0 unreadable || fail=1
  { shuf -n1 unreadable || test $? -ne 1; } && fail=1
fi

# Multiple -n is accepted, should use the smallest value
shuf -n10 -i0-9 -n3 -n20 > exp || framework_failure_
c=$(wc -l < exp) || framework_failure_
test "$c" -eq 3 || { fail=1; echo "Multiple -n failed">&2 ; }

# Test error conditions

# -i and -e must not be used together
: | { shuf -i0-9 -e A B || test $? -ne 1; } &&
  { fail=1; echo "shuf did not detect erroneous -e and -i usage.">&2 ; }
# Test invalid value for -n
: | { shuf -nA || test $? -ne 1; } &&
  { fail=1; echo "shuf did not detect erroneous -n usage.">&2 ; }
# Test multiple -i
{ shuf -i0-9 -n10 -i8-90 || test $? -ne 1; } &&
  { fail=1; echo "shuf did not detect multiple -i usage.">&2 ; }
# Test invalid range
for ARG in '1' 'A' '1-' '1-A'; do
    { shuf -i$ARG || test $? -ne 1; } &&
    { fail=1; echo "shuf did not detect erroneous -i$ARG usage.">&2 ; }
done

# multiple -o are forbidden
{ shuf -i0-9 -o A -o B || test $? -ne 1; } &&
  { fail=1; echo "shuf did not detect erroneous multiple -o usage.">&2 ; }
# multiple random-sources are forbidden
{ shuf -i0-9 --random-source A --random-source B || test $? -ne 1; } &&
  { fail=1; echo "shuf did not detect multiple --random-source usage.">&2 ; }

# Test --repeat option

# --repeat without count should return an indefinite number of lines
shuf --rep -i 0-10 | head -n 1000 > exp || framework_failure_
c=$(wc -l < exp) || framework_failure_
test "$c" -eq 1000 \
  || { fail=1; echo "--repeat does not repeat indefinitely">&2 ; }

# --repeat can output more values than the input range
shuf --rep -i0-9 -n1000 > exp || framework_failure_
c=$(wc -l < exp) || framework_failure_
test "$c" -eq 1000 || { fail=1; echo "--repeat with --count failed">&2 ; }

# Check output values (this is not bullet-proof, but drawing 1000 values
# between 0 and 9 should produce all values, unless there's a bug in shuf
# or a very poor random source, or extremely bad luck)
c=$(sort -nu exp | paste -s -d ' ') || framework_failure_
test "$c" = "0 1 2 3 4 5 6 7 8 9" ||
  { fail=1; echo "--repeat produced bad output">&2 ; }

# check --repeat with non-zero low value
shuf --rep -i222-233 -n2000 > exp || framework_failure_
c=$(sort -nu exp | paste -s -d ' ') || framework_failure_
test "$c" = "222 223 224 225 226 227 228 229 230 231 232 233" ||
 { fail=1; echo "--repeat produced bad output with non-zero low">&2 ; }

# --repeat,-i,count=0 should not fail and produce no output
shuf --rep -i0-9 -n0 > exp || framework_failure_
# file size should be zero (no output from shuf)
test \! -s exp ||
  { fail=1; echo "--repeat,-i0-9,-n0 produced bad output">&2 ; }

# --repeat with -e, without count, should repeat indefinitely
shuf --rep -e A B C D | head -n 1000 > exp || framework_failure_
c=$(wc -l < exp) || framework_failure_
test "$c" -eq 1000 ||
  { fail=1; echo "--repeat,-e does not repeat indefinitely">&2 ; }

# --repeat with STDIN, without count, should repeat indefinitely
printf "A\nB\nC\nD\nE\n" | shuf --rep | head -n 1000 > exp || framework_failure_
c=$(wc -l < exp) || framework_failure_
test "$c" -eq 1000 ||
  { fail=1; echo "--repeat,STDIN does not repeat indefinitely">&2 ; }

# --repeat with STDIN,count - can return move values than input lines
printf "A\nB\nC\nD\nE\n" | shuf --rep -n2000 > exp || framework_failure_
c=$(wc -l < exp) || framework_failure_
test "$c" -eq 2000 ||
  { fail=1; echo "--repeat,STDIN,count failed">&2 ; }

# Check output values (this is not bullet-proof, but drawing 2000 values
# between A and E should produce all values, unless there's a bug in shuf
# or a very poor random source, or extremely bad luck)
c=$(sort -u exp | paste -s -d ' ') || framework_failure_
test "$c" = "A B C D E" ||
  { fail=1; echo "--repeat,STDIN,count produced bad output">&2 ; }

# --repeat,stdin,count=0 should not fail and produce no output
printf "A\nB\nC\nD\nE\n" | shuf --rep -n0 > exp || framework_failure_
# file size should be zero (no output from shuf)
test \! -s exp ||
  { fail=1; echo "--repeat,STDIN,-n0 produced bad output">&2 ; }

# shuf 8.25 mishandles input if stdin is closed, due to glibc bug#15589.
# See coreutils bug#25029.
shuf /dev/null <&- >out || fail=1
compare /dev/null out || fail=1

Exit $fail
