#!/bin/sh

LC_ALL=C ./test-nl_langinfo${EXEEXT} 0 || exit 1

# Test whether a specific traditional locale is installed.
: ${LOCALE_FR=fr_FR}
if test $LOCALE_FR != none; then
  LC_ALL=$LOCALE_FR ./test-nl_langinfo${EXEEXT} 1 || exit 1
fi

# Test whether a specific UTF-8 locale is installed.
: ${LOCALE_FR_UTF8=fr_FR.UTF-8}
if test $LOCALE_FR_UTF8 != none; then
  LC_ALL=$LOCALE_FR_UTF8 ./test-nl_langinfo${EXEEXT} 2 || exit 1
fi

exit 0
