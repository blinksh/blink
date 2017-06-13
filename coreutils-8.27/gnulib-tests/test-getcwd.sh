#!/bin/sh

. "${srcdir=.}/init.sh"; path_prepend_ .

test-getcwd

Exit $?
