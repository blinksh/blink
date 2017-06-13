#!/bin/sh
# Make sure touch can operate on a directory.
# This was broken in the 4.0[efg] test releases.

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ touch

touch . || fail=1
Exit $fail
