#!/bin/sh

# Execute the test only with seekable input stream.
# The behaviour of fflush() on a non-seekable input stream is undefined.
./test-fflush2${EXEEXT} 1 < "$srcdir/test-fflush2.sh" || exit $?
./test-fflush2${EXEEXT} 2 < "$srcdir/test-fflush2.sh" || exit $?
#cat "$srcdir/test-fflush2.sh" | ./test-fflush2${EXEEXT} || exit $?

exit 0
