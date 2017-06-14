#!/bin/sh

./test-fseek${EXEEXT} 1 < "$srcdir/test-fseek.sh" || exit 1
echo hi | ./test-fseek${EXEEXT} || exit 1
exit 0
