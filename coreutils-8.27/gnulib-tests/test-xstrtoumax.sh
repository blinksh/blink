#!/bin/sh
: ${srcdir=.}
. "$srcdir/init.sh"; path_prepend_ .

too_big=99999999999999999999999999999999999999999999999999999999999999999999
result=0

# test xstrtoumax
test-xstrtoumax 1 >> out 2>&1 || result=1
test-xstrtoumax -1 >> out 2>&1 && result=1
test-xstrtoumax 1k >> out 2>&1 || result=1
test-xstrtoumax ${too_big}h >> out 2>&1 && result=1
test-xstrtoumax $too_big >> out 2>&1 && result=1
test-xstrtoumax x >> out 2>&1 && result=1
test-xstrtoumax 9x >> out 2>&1 && result=1
test-xstrtoumax 010 >> out 2>&1 || result=1
test-xstrtoumax MiB >> out 2>&1 || result=1

# Find out how to remove carriage returns from output. Solaris /usr/ucb/tr
# does not understand '\r'.
if echo solaris | tr -d '\r' | grep solais > /dev/null; then
  cr='\015'
else
  cr='\r'
fi

# normalize output
LC_ALL=C tr -d "$cr" < out > k
mv k out

# compare expected output
cat > exp <<EOF
1->1 ()
invalid X argument '-1'
1k->1024 ()
invalid suffix in X argument '${too_big}h'
X argument '$too_big' too large
invalid X argument 'x'
invalid suffix in X argument '9x'
010->8 ()
MiB->1048576 ()
EOF

compare exp out || result=1

Exit $result
