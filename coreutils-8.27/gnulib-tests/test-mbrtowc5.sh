#!/bin/sh
# Test whether the POSIX locale has encoding errors.
LC_ALL=C \
./test-mbrtowc${EXEEXT} 5 || exit
LC_ALL=POSIX \
./test-mbrtowc${EXEEXT} 5
