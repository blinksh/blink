#!/bin/sh

./test-ftello${EXEEXT} 1 < "$srcdir/test-ftello.sh" || exit 1
echo hi | ./test-ftello${EXEEXT} || exit 1
exit 0
