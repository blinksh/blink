#!/bin/sh
: ${srcdir=.}
. "$srcdir/init.sh"; path_prepend_ .

echo Hello world > in.tmp
echo world > xout.tmp

fail=0
# Test with seekable stdin; follow-on process must see remaining data
(test-closein; cat) < in.tmp > out1.tmp || fail=1
cmp out1.tmp in.tmp || fail=1

(test-closein consume; cat) < in.tmp > out2.tmp || fail=1
cmp out2.tmp xout.tmp || fail=1

# Test for lack of error on pipe.  Ignore any EPIPE failures from cat.
cat in.tmp 2>/dev/null | test-closein || fail=1

cat in.tmp 2>/dev/null | test-closein consume || fail=1

# Test for lack of error when nothing is read
test-closein </dev/null || fail=1

test-closein <&- || fail=1

# Test for no error when EOF is read early
test-closein consume </dev/null || fail=1

# Test for error when read fails because no file available
test-closein consume close <&- 2>/dev/null && fail=1

Exit $fail
