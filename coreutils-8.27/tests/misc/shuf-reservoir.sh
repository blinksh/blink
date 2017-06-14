#!/bin/sh
# Exercise shuf's reservoir-sampling code
# NOTE:
#  These tests do not check valid randomness,
#  they just check memory allocation related code.

# Copyright (C) 2013-2017 Free Software Foundation, Inc.

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
expensive_
require_valgrind_

# Only exit with error for leaks when in development mode
# in which case we enable code to suppress inconsequential leaks.
grep '^#define lint 1' "$CONFIG_HEADER" && leaklevel=full || leaklevel=summary

# Run "shuf" with specific number of input lines and output lines
# Check the output for expected number of lines.
run_shuf_n()
{
  INPUT_LINES="$1"
  OUTPUT_LINES="$2"

  # Critical memory-related bugs will cause a segfault here
  # (with varying numbers of input/output lines)
  seq "$INPUT_LINES" | valgrind --leak-check=$leaklevel --error-exitcode=1 \
  shuf -n "$OUTPUT_LINES" -o "out_${INPUT_LINES}_${OUTPUT_LINES}" || return 1

  EXPECTED_LINES="$OUTPUT_LINES"
  test "$INPUT_LINES" -lt "$OUTPUT_LINES" && EXPECTED_LINES="$INPUT_LINES"

  # There is no sure way to verify shuffled output (as it is random).
  # Ensure we have the correct number of all numeric lines non duplicated lines.
  GOOD_LINES=$(grep '^[0-9][0-9]*$' "out_${INPUT_LINES}_${OUTPUT_LINES}" |
               sort -un | wc -l) || framework_failure_
  LINES=$(wc -l < "out_${INPUT_LINES}_${OUTPUT_LINES}") || framework_failure_

  test "$EXPECTED_LINES" -eq "$GOOD_LINES" || return 1
  test "$EXPECTED_LINES" -eq "$LINES" || return 1

  return 0
}

# Test multiple combinations of input lines and output lines.
# (e.g. small number of input lines and large number of output lines,
#  and vice-versa. Also, each reservoir allocation uses a 1024-lines batch,
#  so test 1023/1024/1025 and related values).
TEST_LINES="0 1 5 1023 1024 1025 3071 3072 3073"

for IN_N in $TEST_LINES; do
  for OUT_N in $TEST_LINES; do
    run_shuf_n "$IN_N" "$OUT_N" || {
      fail=1
      echo "shuf-reservoir-sampling failed with IN_N=$IN_N OUT_N=$OUT_N" >&2;
    }
  done
done

Exit $fail
