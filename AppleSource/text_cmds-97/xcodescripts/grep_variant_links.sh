#!/bin/sh
#
# This script phase cannot be run in the "grep" target itself, because Strip/CodeSign/etc are
# after all other phases. Running it in the aggregate target guarantees that the grep variants
# are really linked to the actual stripped/signed grep binary.
#

set -ex

for variant in e f z ze zf bz bze bzf; do
    ln ${DSTROOT}/usr/bin/grep ${DSTROOT}/usr/bin/${variant}grep
    ln ${DSTROOT}/usr/share/man/man1/grep.1 ${DSTROOT}/usr/share/man/man1/${variant}grep.1
done
