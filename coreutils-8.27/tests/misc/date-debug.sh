#!/bin/sh
# Test 'date --debug' option.

# Copyright (C) 2016-2017 Free Software Foundation, Inc.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ date

export LC_ALL=C

## Ensure timezones are supported.
## (NOTE: America/Belize timezone does not change on DST)
test "$(TZ=America/Belize date +%z)" = '-0600' \
    || skip_ 'Timezones database not found'


##
## Test 1: complex date string
##
in1='TZ="Asia/Tokyo" Sun, 90-12-11 + 3 days - 90 minutes'

cat<<EOF>exp1
date: parsed day part: Sun (day ordinal=0 number=0)
date: parsed date part: (Y-M-D) 0090-12-11
date: parsed relative part: +3 day(s)
date: parsed relative part: +3 day(s) -90 minutes
date: input timezone: +09:00 (set from TZ="Asia/Tokyo" in date string)
date: warning: adjusting year value 90 to 1990
date: warning: using midnight as starting time: 00:00:00
date: warning: day (Sun) ignored when explicit dates are given
date: starting date/time: '(Y-M-D) 1990-12-11 00:00:00 TZ=+09:00'
date: warning: when adding relative days, it is recommended to specify 12:00pm
date: after date adjustment (+0 years, +0 months, +3 days),
date:     new date/time = '(Y-M-D) 1990-12-14 00:00:00 TZ=+09:00'
date: '(Y-M-D) 1990-12-14 00:00:00 TZ=+09:00' = 661100400 epoch-seconds
date: after time adjustment (+0 hours, -90 minutes, +0 seconds, +0 ns),
date:     new time = 661095000 epoch-seconds
date: output timezone: +09:00 (set from TZ="Asia/Tokyo" environment value)
date: final: 661095000.000000000 (epoch-seconds)
date: final: (Y-M-D) 1990-12-13 13:30:00 (UTC0)
date: final: (Y-M-D) 1990-12-13 22:30:00 (output timezone TZ=+09:00)
Thu Dec 13 07:30:00 CST 1990
EOF

TZ=America/Belize date --debug -d "$in1" >out1 2>&1 || fail=1

compare exp1 out1 || fail=1

##
## Test 2: Invalid date from Coreutils' FAQ
##         (with explicit timezone added)
in2='TZ="America/Edmonton" 2006-04-02 02:30:00'
cat<<EOF>exp2
date: parsed date part: (Y-M-D) 2006-04-02
date: parsed time part: 02:30:00
date: input timezone: -07:00 (set from TZ="America/Edmonton" in date string)
date: using specified time as starting value: '02:30:00'
date: error: invalid date/time value:
date:     user provided time: '(Y-M-D) 2006-04-02 02:30:00 TZ=-07:00'
date:        normalized time: '(Y-M-D) 2006-04-02 03:30:00 TZ=-07:00'
date:                                             --
date:      possible reasons:
date:        non-existing due to daylight-saving time;
date:        numeric values overflow;
date:        missing timezone
date: invalid date 'TZ="America/Edmonton" 2006-04-02 02:30:00'
EOF

# date should return 1 (error) for invalid date
returns_ 1 date --debug -d "$in2" >out2 2>&1 || fail=1
compare exp2 out2 || fail=1

##
## Test 3: timespec (input always UTC, output is TZ-dependent)
##
in3='@1'
cat<<EOF>exp3
date: parsed number of seconds part: number of seconds: 1
date: input timezone: +00:00 (set from '@timespec' - always UTC0)
date: output timezone: -05:00 (set from TZ="America/Lima" environment value)
date: final: 1.000000000 (epoch-seconds)
date: final: (Y-M-D) 1970-01-01 00:00:01 (UTC0)
date: final: (Y-M-D) 1969-12-31 19:00:01 (output timezone TZ=-05:00)
Wed Dec 31 19:00:01 PET 1969
EOF

TZ=America/Lima date --debug -d "$in3" >out3 2>&1 || fail=1
compare exp3 out3 || fail=1

##
## Parsing a lone number.
## Fixed in gnulib v0.1-1099-gf2d4b5c
## http://git.savannah.gnu.org/cgit/gnulib.git/commit/?id=f2d4b5caa
cat<<EOF>exp4
date: parsed number part: (Y-M-D) 2013-01-01
date: input timezone: +00:00 (set from TZ=UTC0 environment value or -u)
date: warning: using midnight as starting time: 00:00:00
date: starting date/time: '(Y-M-D) 2013-01-01 00:00:00 TZ=+00:00'
date: '(Y-M-D) 2013-01-01 00:00:00 TZ=+00:00' = 1356998400 epoch-seconds
date: output timezone: +00:00 (set from TZ=UTC0 environment value or -u)
date: final: 1356998400.000000000 (epoch-seconds)
date: final: (Y-M-D) 2013-01-01 00:00:00 (UTC0)
date: final: (Y-M-D) 2013-01-01 00:00:00 (output timezone TZ=+00:00)
Tue Jan  1 00:00:00 UTC 2013
EOF

date -u --debug -d '20130101' >out4 2>&1 || fail=1
compare exp4 out4 || fail=1


##
## Parsing a relative number after a timezone string
## Fixed in gnulib v0.1-1100-g5c438e8
## http://git.savannah.gnu.org/cgit/gnulib.git/commit/?id=5c438e8ce7d
cat<<EOF>exp5
date: parsed date part: (Y-M-D) 2013-10-30
date: parsed time part: 00:00:00
date: parsed relative part: -8 day(s)
date: parsed zone part: TZ=+00:00
date: input timezone: +00:00 (set from parsed date/time string)
date: using specified time as starting value: '00:00:00'
date: starting date/time: '(Y-M-D) 2013-10-30 00:00:00 TZ=+00:00'
date: warning: when adding relative days, it is recommended to specify 12:00pm
date: after date adjustment (+0 years, +0 months, -8 days),
date:     new date/time = '(Y-M-D) 2013-10-22 00:00:00 TZ=+00:00'
date: '(Y-M-D) 2013-10-22 00:00:00 TZ=+00:00' = 1382400000 epoch-seconds
date: output timezone: +00:00 (set from TZ=UTC0 environment value or -u)
date: final: 1382400000.000000000 (epoch-seconds)
date: final: (Y-M-D) 2013-10-22 00:00:00 (UTC0)
date: final: (Y-M-D) 2013-10-22 00:00:00 (output timezone TZ=+00:00)
2013-10-22
EOF

in5='2013-10-30 00:00:00 UTC -8 days'
date -u --debug +%F -d "$in5" >out5 2>&1 || fail=1
compare exp5 out5 || fail=1

##
## Explicitly warn about unexpected day/month shifts.
## added in gnulib v0.1-1101-gf14eff1
## http://git.savannah.gnu.org/cgit/gnulib.git/commit/?id=f14eff1b3cde2b
TOOLONG='it is recommended to specify the 15th of the months'
cat<<EOF>exp6
date: parsed date part: (Y-M-D) 2016-10-31
date: parsed relative part: -1 month(s)
date: input timezone: +00:00 (set from TZ=UTC0 environment value or -u)
date: warning: using midnight as starting time: 00:00:00
date: starting date/time: '(Y-M-D) 2016-10-31 00:00:00 TZ=+00:00'
date: warning: when adding relative months/years, $TOOLONG
date: after date adjustment (+0 years, -1 months, +0 days),
date:     new date/time = '(Y-M-D) 2016-10-01 00:00:00 TZ=+00:00'
date: warning: month/year adjustment resulted in shifted dates:
date:      adjusted Y M D: 2016 09 31
date:    normalized Y M D: 2016 10 01
date: '(Y-M-D) 2016-10-01 00:00:00 TZ=+00:00' = 1475280000 epoch-seconds
date: output timezone: +00:00 (set from TZ=UTC0 environment value or -u)
date: final: 1475280000.000000000 (epoch-seconds)
date: final: (Y-M-D) 2016-10-01 00:00:00 (UTC0)
date: final: (Y-M-D) 2016-10-01 00:00:00 (output timezone TZ=+00:00)
Sat Oct  1 00:00:00 UTC 2016
EOF

date -u --debug -d '2016-10-31 - 1 month' >out6 2>&1 || fail=1
compare exp6 out6 || fail=1


##
## Explicitly warn about crossing DST boundaries.
## added in gnulib v0.1-1102-g30a55dd
## http://git.savannah.gnu.org/cgit/gnulib.git/commit/?id=30a55dd72dad2
TOOLONG1='(set from TZ="America/New_York" environment value, dst)'
TOOLONG2='it is recommended to specify the 15th of the months'
cat<<EOF>exp7
date: parsed date part: (Y-M-D) 2016-06-01
date: parsed local_zone part: DST changed: is-dst=1
date: parsed relative part: +6 month(s)
date: input timezone: -04:00 $TOOLONG1
date: warning: using midnight as starting time: 00:00:00
date: starting date/time: '(Y-M-D) 2016-06-01 00:00:00 TZ=-04:00'
date: warning: when adding relative months/years, $TOOLONG2
date: after date adjustment (+0 years, +6 months, +0 days),
date:     new date/time = '(Y-M-D) 2016-11-30 23:00:00 TZ=-04:00'
date: warning: daylight saving time changed after date adjustment
date: warning: month/year adjustment resulted in shifted dates:
date:      adjusted Y M D: 2016 12 01
date:    normalized Y M D: 2016 11 30
date: '(Y-M-D) 2016-11-30 23:00:00 TZ=-04:00' = 1480564800 epoch-seconds
date: output timezone: -05:00 (set from TZ="America/New_York" environment value)
date: final: 1480564800.000000000 (epoch-seconds)
date: final: (Y-M-D) 2016-12-01 04:00:00 (UTC0)
date: final: (Y-M-D) 2016-11-30 23:00:00 (output timezone TZ=-05:00)
2016-11-30
EOF

in7='2016-06-01 EDT + 6 months'
TZ=America/New_York date --debug -d "$in7" +%F >out7 2>&1 || fail=1
compare exp7 out7 || fail=1


## fix local timezone debug messages.
## fixed in git v0.1-1103-gc56e7fb
## http://git.savannah.gnu.org/cgit/gnulib.git/commit/?id=c56e7fbb032

cat<<EOF>exp8_1
date: parsed date part: (Y-M-D) 2011-12-11
date: parsed local_zone part: DST unchanged
date: input timezone: +02:00 (set from TZ="Europe/Helsinki" environment value)
date: warning: using midnight as starting time: 00:00:00
date: starting date/time: '(Y-M-D) 2011-12-11 00:00:00 TZ=+02:00'
date: '(Y-M-D) 2011-12-11 00:00:00 TZ=+02:00' = 1323554400 epoch-seconds
date: output timezone: +02:00 (set from TZ="Europe/Helsinki" environment value)
date: final: 1323554400.000000000 (epoch-seconds)
date: final: (Y-M-D) 2011-12-10 22:00:00 (UTC0)
date: final: (Y-M-D) 2011-12-11 00:00:00 (output timezone TZ=+02:00)
Sun Dec 11 00:00:00 EET 2011
EOF

TZ=Europe/Helsinki date --debug -d '2011-12-11 EET' >out8_1 2>&1 || fail=1
compare exp8_1 out8_1 || fail=1

TOOLONG='(set from TZ="Europe/Helsinki" environment value, dst)'
cat<<EOF>exp8_2
date: parsed date part: (Y-M-D) 2011-06-11
date: parsed local_zone part: DST changed: is-dst=1
date: input timezone: +03:00 $TOOLONG
date: warning: using midnight as starting time: 00:00:00
date: starting date/time: '(Y-M-D) 2011-06-11 00:00:00 TZ=+03:00'
date: '(Y-M-D) 2011-06-11 00:00:00 TZ=+03:00' = 1307739600 epoch-seconds
date: output timezone: +02:00 (set from TZ="Europe/Helsinki" environment value)
date: final: 1307739600.000000000 (epoch-seconds)
date: final: (Y-M-D) 2011-06-10 21:00:00 (UTC0)
date: final: (Y-M-D) 2011-06-11 00:00:00 (output timezone TZ=+02:00)
Sat Jun 11 00:00:00 EEST 2011
EOF

TZ=Europe/Helsinki date --debug -d '2011-06-11 EEST' >out8_2 2>&1 || fail=1
compare exp8_2 out8_2 || fail=1



## fix debug message on lone year number (The "2011" part).
## fixed in gnulib v0.1-1104-g15b8f30
## http://git.savannah.gnu.org/cgit/gnulib.git/commit/?id=15b8f3046a25
##
## NOTE:
## When the date 'Apr 11' is parsed, the year part will be the
## current year. The expected output thus depends on the year
## the test is being run. We'll use sed to change it to XXXX.
cat<<EOF>exp9
date: parsed date part: (Y-M-D) XXXX-04-11
date: parsed time part: 22:59:00
date: parsed number part: year: 2011
date: input timezone: +00:00 (set from TZ=UTC0 environment value or -u)
date: using specified time as starting value: '22:59:00'
date: starting date/time: '(Y-M-D) 2011-04-11 22:59:00 TZ=+00:00'
date: '(Y-M-D) 2011-04-11 22:59:00 TZ=+00:00' = 1302562740 epoch-seconds
date: output timezone: +00:00 (set from TZ=UTC0 environment value or -u)
date: final: 1302562740.000000000 (epoch-seconds)
date: final: (Y-M-D) 2011-04-11 22:59:00 (UTC0)
date: final: (Y-M-D) 2011-04-11 22:59:00 (output timezone TZ=+00:00)
Mon Apr 11 22:59:00 UTC 2011
EOF

date -u --debug -d 'Apr 11 22:59:00 2011' >out9_t 2>&1 || fail=1
sed '1s/(Y-M-D) [0-9][0-9][0-9][0-9]-/(Y-M-D) XXXX-/' out9_t > out9 \
    || framework_failure_
compare exp9 out9 || fail=1


Exit $fail
