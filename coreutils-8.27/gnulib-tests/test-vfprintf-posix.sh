#!/bin/sh

tmpfiles=""
trap 'rm -fr $tmpfiles' 1 2 3 15

tmpfiles="$tmpfiles t-vfprintf-posix.tmp t-vfprintf-posix.out"
./test-vfprintf-posix${EXEEXT} > t-vfprintf-posix.tmp || exit 1
LC_ALL=C tr -d '\r' < t-vfprintf-posix.tmp > t-vfprintf-posix.out || exit 1

: ${DIFF=diff}
${DIFF} "${srcdir}/test-printf-posix.output" t-vfprintf-posix.out
result=$?

rm -fr $tmpfiles

exit $result
