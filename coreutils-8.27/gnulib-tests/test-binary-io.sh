#!/bin/sh

tmpfiles=""
trap 'rm -fr $tmpfiles' 1 2 3 15

tmpfiles="$tmpfiles t-bin-out0.tmp t-bin-out1.tmp"
./test-binary-io${EXEEXT} 1 > t-bin-out1.tmp || exit 1
cmp t-bin-out0.tmp t-bin-out1.tmp > /dev/null || exit 1

rm -fr $tmpfiles

exit 0
