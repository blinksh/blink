#!/bin/sh

tmpfile=
trap 'rm -fr $tmpfile' 1 2 3 15

tmpfile=test-fpending.t

./test-fpending${EXEEXT} > $tmpfile || exit 1

rm -fr $tmpfile

exit 0
