#!/bin/sh

./test-freadseek${EXEEXT} 5 19 6 7 18 9 19 < "$srcdir/test-freadseek.sh" || exit 1
cat "$srcdir/test-freadseek.sh" | ./test-freadseek${EXEEXT} 5 19 6 7 18 9 19 || exit 1
exit 0
