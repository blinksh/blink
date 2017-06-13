#!/bin/sh
. "${srcdir=.}/init.sh"; path_prepend_ .

fail=0

test-readtokens || fail=1

# Simplest case.
echo a:b:c: > exp || fail=1
printf a:b:c | test-readtokens : > out 2>&1 || fail=1
compare exp out || fail=1

# Use NUL as the delimiter.
echo a:b:c: > exp || fail=1
printf 'a\0b\0c' | test-readtokens '\0' > out 2>&1 || fail=1
compare exp out || fail=1

# Two delimiter bytes, and adjacent delimiters in the input.
echo a:b:c: > exp || fail=1
printf a:-:b-:c:: | test-readtokens :- > out 2>&1 || fail=1
compare exp out || fail=1

Exit $fail
