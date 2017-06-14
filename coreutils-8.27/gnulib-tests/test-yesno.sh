#!/bin/sh
: ${srcdir=.}
. "$srcdir/init.sh"; path_prepend_ .

# For now, only test with C locale
LC_ALL=C
export LC_ALL

# Find out how to remove carriage returns from output. Solaris /usr/ucb/tr
# does not understand '\r'.
if echo solaris | tr -d '\r' | grep solais > /dev/null; then
  cr='\015'
else
  cr='\r'
fi

# Test with seekable stdin; the follow-on process must see remaining data.
tr @ '\177' <<EOF > in.tmp
nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn - entire line consumed
y@n - backspace does not change result
y
does not match either yesexpr or noexpr
n
EOF

cat <<EOF > xout.tmp
N
Y
Y
N
n
EOF

fail=0
(test-yesno; test-yesno 3; cat) < in.tmp > out1.tmp || fail=1
LC_ALL=C tr -d "$cr" < out1.tmp > out.tmp || fail=1
cmp xout.tmp out.tmp || fail=1

(test-yesno 3; test-yesno; cat) < in.tmp > out1.tmp || fail=1
LC_ALL=C tr -d "$cr" < out1.tmp > out.tmp || fail=1
cmp xout.tmp out.tmp || fail=1

# Test for behavior on pipe
cat <<EOF > xout.tmp
Y
N
EOF
echo yes | test-yesno 2 > out1.tmp || fail=1
LC_ALL=C tr -d "$cr" < out1.tmp > out.tmp || fail=1
cmp xout.tmp out.tmp || fail=1

# Test for behavior with no EOL at EOF
cat <<EOF > xout.tmp
Y
EOF
printf y | test-yesno 1 > out1.tmp || fail=1
LC_ALL=C tr -d "$cr" < out1.tmp > out.tmp || fail=1
cmp xout.tmp out.tmp || fail=1

# Test for behavior on EOF
cat <<EOF > xout.tmp
N
EOF
test-yesno </dev/null > out1.tmp || fail=1
LC_ALL=C tr -d "$cr" < out1.tmp > out.tmp || fail=1
cmp xout.tmp out.tmp || fail=1

# Test for behavior when stdin is closed
test-yesno 0 <&- > out1.tmp 2> err.tmp && fail=1
LC_ALL=C tr -d "$cr" < out1.tmp > out.tmp || fail=1
cmp xout.tmp out.tmp || fail=1
test -s err.tmp || fail=1

Exit $fail
