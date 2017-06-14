#!/bin/sh

./test-ftell${EXEEXT} 1 < "$srcdir/test-ftell.sh" || exit 1
echo hi | ./test-ftell${EXEEXT} || exit 1
exit 0
