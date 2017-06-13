#!/bin/sh

# Test whether a specific Turkish locale is installed.
: ${LOCALE_TR_UTF8=tr_TR.UTF-8}
if test $LOCALE_TR_UTF8 = none; then
  if test -f /usr/bin/localedef; then
    echo "Skipping test: no turkish Unicode locale is installed"
  else
    echo "Skipping test: no turkish Unicode locale is supported"
  fi
  exit 77
fi

LC_ALL=$LOCALE_TR_UTF8 \
./test-mbscasecmp${EXEEXT}
