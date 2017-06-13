#!/bin/sh
# Create the factor test scripts.

# Copyright (C) 2012-2017 Free Software Foundation, Inc.

test_name=$1
template=$2

# Extract the test name: remove .sh suffix from the basename.
t=`echo "$test_name"|sed 's,.*/,,;s,\.sh$,,'`

# prefix of 2^64
p=184467440737

# prefix of 2^96
q=79228162514264337593543

# Each of these numbers has a Pollard rho factor larger than 2^64,
# and thus exercises some hard-to-reach code in factor.c.
t1=170141183460469225450570946617781744489
t2=170141183460469229545748130981302223887

# Factors of the above:
# t1: 9223372036854775421 18446744073709551709
# t2: 9223372036854775643 18446744073709551709

# Each test is a triple: lo, hi, sha1 of result.
# The test script, run.sh, runs seq lo hi|factor|sha1sum
# and verifies that the actual and expected checksums are the same.
# New tests must be added to tests/local.mk (factor_tests), too.
case $t in
  t00) set            0     10000000 a451244522b1b662c86cb3cbb55aee3e085a61a0 ;;
  t01) set     10000000     20000000 c792a2e02f1c8536b5121f624b04039d20187016 ;;
  t02) set     20000000     30000000 8115e8dff97d1674134ec054598d939a2a5f6113 ;;
  t03) set     30000000     40000000 fe7b832c8e0ed55035152c0f9ebd59de73224a60 ;;
  t04) set     40000000     50000000 b8786d66c432e48bc5b342ee3c6752b7f096f206 ;;
  t05) set     50000000     60000000 a74fe518c5f79873c2b9016745b88b42c8fd3ede ;;
  t06) set     60000000     70000000 689bc70d681791e5d1b8ac1316a05d0c4473d6db ;;
  t07) set     70000000     80000000 d370808f2ab8c865f64c2ff909c5722db5b7d58d ;;
  t08) set     80000000     90000000 7978aa66bf2bdb446398336ea6f02605e9a77581 ;;
  t09) set          $t1          $t1 4622287c5f040cdb7b3bbe4d19d29a71ab277827 ;;
  t10) set          $t2          $t2 dea308253708b57afad357e8c0d2a111460ef50e ;;
  t11) set ${p}08551616 ${p}08651615 66c57cd58f4fb572df7f088d17e4f4c1d4f01bb1 ;;
  t12) set ${p}08651616 ${p}08751615 729228e693b1a568ecc85b199927424c7d16d410 ;;
  t13) set ${p}08751616 ${p}08851615 5a0c985017c2d285e4698f836f5a059e0b684563 ;;
  t14) set ${p}08851616 ${p}08951615 0482295c514e371c98ce9fd335deed0c9c44a4f4 ;;
  t15) set ${p}08951616 ${p}09051615 9c0e1105ac7c45e27e7bbeb5e213f530d2ad1a71 ;;
  t16) set ${p}09051616 ${p}09151615 604366d2b1d75371d0679e6a68962d66336cd383 ;;
  t17) set ${p}09151616 ${p}09251615 9192d2bdee930135b28d7160e6d395a7027871da ;;
  t18) set ${p}09251616 ${p}09351615 bcf56ae55d20d700690cff4d3327b78f83fc01bf ;;
  t19) set ${p}09351616 ${p}09451615 16b106398749e5f24d278ba7c58229ae43f650ac ;;
  t20) set ${p}09451616 ${p}09551615 ad2c6ed63525f8e7c83c4c416e7715fa1bebc54c ;;
  t21) set ${p}09551616 ${p}09651615 2b6f9c11742d9de045515a6627c27a042c49f8ba ;;
  t22) set ${p}09651616 ${p}09751615 54851acd51c4819beb666e26bc0100dc9adbc310 ;;
  t23) set ${p}09751616 ${p}09851615 6939c2a7afd2d81f45f818a159b7c5226f83a50b ;;
  t24) set ${p}09851616 ${p}09951615 0f2c8bc011d2a45e2afa01459391e68873363c6c ;;
  t25) set ${p}09951616 ${p}10051615 630dc2ad72f4c222bad1405e6c5bea590f92a98c ;;
  t26) set   ${q}940336   ${q}942335 63cbd6313d78247b04d63bbbac50cb8f8d33ff71 ;;
  t27) set   ${q}942336   ${q}944335 0d03d63653767173182491b86fa18f8f680bb036 ;;
  t28) set   ${q}944336   ${q}946335 ca43bd38cd9f97cc5bb63613cb19643578640f0b ;;
  t29) set   ${q}946336   ${q}948335 86d59545a0c13567fa96811821ea5cde950611b1 ;;
  t30) set   ${q}948336   ${q}950335 c3740e702fa9c97e6cf00150860e0b936a141a6b ;;
  t31) set   ${q}950336   ${q}952335 551c3c4c4640d86fda311b5c3006dac45505c0ce ;;
  t32) set   ${q}952336   ${q}954335 b1b0b00463c2f853d70ef9c4f7a96de5cb614156 ;;
  t33) set   ${q}954336   ${q}956335 8938a484a9ef6bb16478091d294fcde9f8ecea69 ;;
  t34) set   ${q}956336   ${q}958335 d1ae6bc712d994f35edf55c785d71ddf31f16535 ;;
  t35) set   ${q}958336   ${q}960335 2374919a89196e1fce93adfe779cb4664556d4b6 ;;
  t36) set   ${q}960336   ${q}962335 569e4363e8d9e8830a187d9ab27365eef08abde1 ;;
  *)
    echo "$0: error: unknown test: '$test_name' -> '$t'" >&2
    exit 1
    ;;
esac

TEMPLATE="TEST SCRIPT DERIVED FROM THE TEMPLATE $template"

# Create the test script from the template for this test
# by substituting the START, the END and the CKSUM.
exec sed \
  -e "s/__START__/$1/" \
  -e "s/__END__/$2/" \
  -e "s/__CKSUM__/$3/" \
  -e "s!__TEMPLATE__!$TEMPLATE!" "$template"
