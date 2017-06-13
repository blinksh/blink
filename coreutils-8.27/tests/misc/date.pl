#!/usr/bin/perl
# Test "date".

# Copyright (C) 2005-2017 Free Software Foundation, Inc.

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

use strict;

(my $ME = $0) =~ s|.*/||;

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

# Export TZ=UTC0 so that zone-dependent strings match.
$ENV{TZ} = 'UTC0';

my $t0 = '08:17:48';
my $d0 = '1997-01-19';
my $d1 = "$d0 $t0 +0";
my $dT = "${d0}T$t0+0"; # ISO 8601 with "T" separator

my $ts = '08:17:49'; # next second
my $tm = '08:18:48'; # next minute
my $th = '09:17:48'; # next hour

my $dd = '1997-01-20'; # next day
my $dw = '1997-01-26'; # next week
my $dm = '1997-02-19'; # next month
my $dy = '1998-01-19'; # next month

my $fmt = "'+%Y-%m-%d %T'";

my @Tests =
    (
     # test-name, [option, option, ...] {OUT=>"expected-output"}
     #
     ['1', "-d '$d1' +'%% %a %A %b %B'", {OUT=>"% Sun Sunday Jan January"}],

     # [Actually, skip it on *all* systems. -- this Perl code is run at
     # distribution-build-time, not at configure/test time.  ]

     # Skip the test of %c on SunOS4 systems.  Such systems would fail this
     # test because their underlying strftime doesn't handle the %c format
     # properly.  GNU strftime must rely on the underlying host library
     # function to get locale-dependent behavior, as strftime is the only
     # portable interface to that behavior.
     # ['2', "-d '$d1' +'%c'", {OUT=>"Sun Jan 19 $t0 1997"}],

     ['3', "-d '$d1' +'%d_%D_%e_%h_%H'", {OUT=>"19_01/19/97_19_Jan_08"}],
     ['3T',"-d '$dT' +'%d_%D_%e_%h_%H'", {OUT=>"19_01/19/97_19_Jan_08"}],

     ['4', "-d '$d1' +'%I_%j_%k_%l_%m'", {OUT=>"08_019_ 8_ 8_01"}],
     ['5', "-d '$d1' +'%M_%n_%p_%r'", {OUT=>"17_\n_AM_$t0 AM"}],
     ['6', "-d '$d1' +'%s_%S_%t_%T'", {OUT=>"853661868_48_\t_$t0"}],
     ['7', "-d '$d1' +'%U_%V_%w_%W'", {OUT=>"03_03_0_02"}],
     ['8', "-d '$d1' +'%x_%X_%y_%Y'", {OUT=>"01/19/97_${t0}_97_1997"}],
     ['9', "-d '$d1' +'%z'", {OUT=>"+0000"}],

     ['leap-1', "--date '02/29/1996 1 year' +%Y-%m-%d", {OUT=>"1997-03-01"}],

     ['U95-1', "--date '1995-1-1' +%U", {OUT=>"01"}],
     ['U95-2', "--date '1995-1-7' +%U", {OUT=>"01"}],
     ['U95-3', "--date '1995-1-8' +%U", {OUT=>"02"}],

     ['U92-1', "--date '1992-1-1' +%U", {OUT=>"00"}],
     ['U92-2', "--date '1992-1-4' +%U", {OUT=>"00"}],
     ['U92-3', "--date '1992-1-5' +%U", {OUT=>"01"}],

     ['V92-1', "--date '1992-1-1' +%V", {OUT=>"01"}],
     ['V92-2', "--date '1992-1-5' +%V", {OUT=>"01"}],
     ['V92-3', "--date '1992-1-6' +%V", {OUT=>"02"}],

     ['W92-1', "--date '1992-1-1' +%W", {OUT=>"00"}],
     ['W92-2', "--date '1992-1-5' +%W", {OUT=>"00"}],
     ['W92-3', "--date '1992-1-6' +%W", {OUT=>"01"}],

     ['q-1', "--date '2016-1-1' +%q", {OUT=>"1"}],
     ['q-2', "--date '2016-4-1' +%q", {OUT=>"2"}],
     ['q-3', "--date '2016-7-1' +%q", {OUT=>"3"}],
     ['q-4', "--date '2016-10-1' +%q", {OUT=>"4"}],

     ['millen-1', "--date '1998-1-1 3 years' +%Y", {OUT=>"2001"}],

     ['rel-0', "-d '$d1 now' '+%Y-%m-%d %T'", {OUT=>"$d0 $t0"}],

     ['rel-1a', "-d '$d1 yesterday' $fmt", {OUT=>"1997-01-18 $t0"}],
     ['rel-1b', "-d '$d1 tomorrow' $fmt", {OUT=>"1997-01-20 $t0"}],

     ['rel-2a', "-d '$d1 6 years ago' $fmt", {OUT=>"1991-01-19 $t0"}],
     ['rel-2b', "-d '$d1 7 months ago' $fmt", {OUT=>"1996-06-19 $t0"}],
     ['rel-2c', "-d '$d1 8 weeks ago' $fmt", {OUT=>"1996-11-24 $t0"}],
     ['rel-2d', "-d '$d1 1 day ago' $fmt", {OUT=>"1997-01-18 $t0"}],
     ['rel-2e', "-d '$d1 2 hours ago' $fmt", {OUT=>"$d0 06:17:48"}],
     ['rel-2f', "-d '$d1 3 minutes ago' $fmt", {OUT=>"$d0 08:14:48"}],
     ['rel-2g', "-d '$d1 4 seconds ago' $fmt", {OUT=>"$d0 08:17:44"}],

     ['rel-3a', "-d '$d1 4 seconds ago' $fmt", {OUT=>"$d0 08:17:44"}],

     # This has always worked, ...
     ['rel-1day',  "-d '20050101  1 day'  +%F", {OUT=>"2005-01-02"}],
     # ...but up to coreutils-6.9, this was rejected due to the "+".
     ['rel-plus1', "-d '20050101 +1 day'  +%F", {OUT=>"2005-01-02"}],

     ['next-s', "-d '$d1 next second' '+%Y-%m-%d %T'", {OUT=>"$d0 $ts"}],
     ['next-m', "-d '$d1 next minute' '+%Y-%m-%d %T'", {OUT=>"$d0 $tm"}],
     ['next-h', "-d '$d1 next hour'   '+%Y-%m-%d %T'", {OUT=>"$d0 $th"}],
     ['next-d', "-d '$d1 next day'    '+%Y-%m-%d %T'", {OUT=>"$dd $t0"}],
     ['next-w', "-d '$d1 next week'   '+%Y-%m-%d %T'", {OUT=>"$dw $t0"}],
     ['next-mo', "-d '$d1 next month' '+%Y-%m-%d %T'", {OUT=>"$dm $t0"}],
     ['next-y', "-d '$d1 next year'   '+%Y-%m-%d %T'", {OUT=>"$dy $t0"}],

     ['utc-0', "-u -d '08/01/97 6:00' '+%D,%H:%M'", {OUT=>"08/01/97,06:00"},
               {ENV => 'TZ=UTC+4'}],

     ['utc-0a', "-u -d '08/01/97 6:00 UTC +4 hours' '+%D,%H:%M'",
      {OUT=>"08/01/97,10:00"}],
     # Make sure --file=FILE works with -u.
     ['utc-1', "-u --file=f '+%Y-%m-%d %T'",
      {AUX=>{f=>"$d0 $t0\n$d0 $t0"}},
      {OUT=>"$d0 $t0\n$d0 $t0"},
      {ENV => 'TZ=UTC+1'}],

     ['utc-1a', "-u --file=f '+%Y-%m-%d %T'",
      {AUX=>{f=>"$d0 $t0 UTC +1 hour\n$d0 $t0 UTC +1 hour"}},
      {OUT=>"$d0 $th\n$d0 $th"}],

     # From the examples in the documentation.
     ['date2sec-0', "-d '1970-01-01 00:00:01' +%s", {OUT=>"7201"},
      {ENV => 'TZ=UTC+2'}],

     # Same as above, but don't rely on TZ in environment.
     ['date2sec-0a', "-d '1970-01-01 00:00:01 UTC +2 hours' +%s",
      {OUT=>"7201"}],

     ['date2sec-1', "-d 2000-01-01 +%s", {OUT=>"946684800"}],
     ['sec2date-0', "-d '1970-01-01 UTC 946684800 sec' +'%Y-%m-%d %T %z'",
      {OUT=>"2000-01-01 00:00:00 +0000"}],

     ['this-m', "-d '$d0 $t0 this minute' $fmt", {OUT=>"$d0 $t0"}],
     ['this-h', "-d '$d0 $t0 this hour' $fmt", {OUT=>"$d0 $t0"}],
     ['this-w', "-d '$d0 $t0 this week' $fmt", {OUT=>"$d0 $t0"}],
     ['this-mo', "-d '$d0 $t0 this month' $fmt", {OUT=>"$d0 $t0"}],
     ['this-y', "-d '$d0 $t0 this year' $fmt", {OUT=>"$d0 $t0"}],

     ['risks-1', "-d 'Nov 10 1996' $fmt", {OUT=>"1996-11-10 00:00:00"}],

     # This one would pass if TZ (with any, or even no, value) were in
     # the environment.
     ['regress-1', "-u -d '1996-11-10 0:00:00 +0' $fmt",
     {OUT=>"1996-11-10 00:00:00"},
     {ENV =>'LANG=C'}],


     ['datevtime-1', "-d 000909 $fmt", {OUT=>"2000-09-09 00:00:00"}],

     # test for RFC-822 conformance
     ['rfc822-1', "-R -d '$d1'", {OUT=>"Sun, 19 Jan 1997 08:17:48 +0000"},
      # Solaris 5.9's /bin/sh emits this diagnostic to stderr
      # if you don't have support for the named locale.
      {ERR_SUBST => q!s/^couldn't set locale correctly\n//!},
      {ENV => 'LC_ALL=de_DE TZ=UTC0'}],

     # Relative seconds, with time.  fixed in 2.0j
     ['relative-1', "--utc -d '1970-01-01 00:00:00 UTC +961062237 sec' $fmt",
      {OUT=>"2000-06-15 09:43:57"}],

     # Relative seconds, no time.
     ['relative-2', "--utc -d '1970-01-01 UTC +961062237 sec' $fmt",
      {OUT=>"2000-06-15 09:43:57"},
      {ENV => 'TZ=UTC+1'}],

     # Relative days, no time, across time zones.
     ['relative-3', "-I -d '2006-04-23 21 days ago'", {OUT=>"2006-04-02"},
         {ENV=>'TZ=PST8PDT,M4.1.0,M10.5.0'}],

     # This would infloop (or appear to) prior to coreutils-4.5.5,
     # due to a bug in strftime.c.
     ['wide-fmt', "-d '1999-06-01'", '+%3004Y', {OUT=>'0' x 3000 . "1999"}],

     # Ensure that we can parse MONTHNAME-DAY-YEAR.
     ['moname-d-y', '--iso -d May-23-2003', {OUT=>"2003-05-23"}],
     ['moname-d-y-r', '--rfc-3339=date -d May-23-2003', {OUT=>"2003-05-23"}],

     ['epoch', '--iso=sec -d @31536000',
      {OUT=>"1971-01-01T00:00:00+00:00"}],
     ['epoch-r', '--rfc-3339=sec -d @31536000',
      {OUT=>"1971-01-01 00:00:00+00:00"}],

     ['ns-10', '--iso=ns', '-d "1969-12-31 13:00:00.00000001-1100"',
      {OUT=>"1970-01-01T00:00:00,000000010+00:00"}],
     ['ns-10-r', '--rfc-3339=ns', '-d "1969-12-31 13:00:00.00000001-1100"',
      {OUT=>"1970-01-01 00:00:00.000000010+00:00"}],

     ['ns-max32', '--iso=ns', '-d "2038-01-19 03:14:07.999999999"',
      {OUT=>"2038-01-19T03:14:07,999999999+00:00"}],
     ['ns-max32-r', '--rfc-3339=ns', '-d "2038-01-19 03:14:07.999999999"',
      {OUT=>"2038-01-19 03:14:07.999999999+00:00"}],

     ['tz-1', '+%:::z', {OUT=>"-12:34:56"}, {ENV=>'TZ=XXX12:34:56'}],

     ['tz-2', '+%:::z', {OUT=>"+12:34:56"}, {ENV=>'TZ=XXX-12:34:56'}],

     ['tz-3', '+%::z', {OUT=>"+01:02:03"}, {ENV=>'TZ=XXX-1:02:03'}],

     ['tz-4', '+%:::z', {OUT=>"+12"}, {ENV=>'TZ=XXX-12'}],

     ['tz-5', '+%:z', {OUT=>"-00:01"}, {ENV=>'TZ=XXX0:01'}],

     # Accept %:z with a field width before the ':'.
     ['tz-5w','+%8:z', {OUT=>"-0000:01"}, {ENV=>'TZ=XXX0:01'}],
     # Don't recognize %:z with a field width between the ':' and the 'z'.
     ['tz-5wf', '+%:8z', {OUT=>"%:8z"}, {ENV=>'TZ=XXX0:01'}],

     # Test alphabetic timezone abbrv
     ['tz-6', '+%Z', {OUT=>"UTC"}],
     ['tz-7', '+%Z', {OUT=>"JST"}, {ENV=>'TZ=JST-9'}],

     ['ns-relative',
      '--iso=ns',
      "-d'1970-01-01 00:00:00.1234567 UTC +961062237.987654321 sec'",
      {OUT=>"2000-06-15T09:43:58,111111021+00:00"}],
     ['ns-relativer', '--rfc-3339=ns',
      "-d'1970-01-01 00:00:00.1234567 UTC +961062237.987654321 sec'",
      {OUT=>"2000-06-15 09:43:58.111111021+00:00"}],

     # Since coreutils/lib/getdate.y revision 1.96 (post-coreutils-5.3.0),
     # a command like the following would mistakenly exit nonzero with an
     # 'invalid date ...' diagnostic, but when run in a time zone for
     # which daylight savings time is in effect for the starting date.
     # Unfortunately (for ease of testing), if you set TZ at all, this
     # failure is not triggered, hence the removal of TZ from the environment.
     ['cross-dst', "-d'2005-03-27 +1 day'", '+%Y', {OUT=>"2005"},
                  {ENV_DEL => 'TZ'},
                  ],

     ['empty-fmt', '+', {OUT=>""}],

     ['neg-secs', '-d @-22 +%05s', {OUT=>"-0022"}],
     ['neg-secs2', '-d @-22 +%_5s', {OUT=>"  -22"}],

     # FIXME: Ensure date doesn't print uninitialized data
     # for an out-of-range date.  This test is currently
     # disabled as various systems have different limits
     # for localtime(), and we can't use perl for example
     # to determine those limits as it doesn't always call
     # down to the system localtime() as it has configure
     # time checks and settings itself for these limits.
     #['uninit-64', "-d \@72057594037927935",
     # {OUT=>''},
     # # Use ERR_SUBST to get around fact that the diagnostic
     # # you get on a system with 32-bit time_t is not the same as
     # # the one you get for a system where it's 64 bits wide:
     # # - date: time 72057594037927935 is out of range
     # # + date: invalid date '@72057594037927935'
     # {ERR_SUBST => 's/.*//'},
     # {ERR => "\n"},
     # {EXIT => 1},
     #],

     ['fill-1', '-d 1999-12-08 +%_3d', {OUT=>'  8'}],
     ['fill-2', '-d 1999-12-08 +%03d', {OUT=>'008'}],

     # Test the combination of the to-upper-case modifier (^) and a conversion
     # specifier that expands to a string containing lower case characters.
     ['subfmt-up1', '-d "1999-12-08 7:30" "+%^c"',
      # Solaris 5.9 prints 'WED DEC 08 07:30:00 1999', while
      # most others print  'WED DEC  8 07:30:00 1999'.
      {OUT_SUBST => 's/ [ 0]8.*//'},
      {OUT=>'WED DEC'}],

     ['invalid-high-bit-set', "-d '\xb0'",
      {ERR => "date: invalid date '\\260'\n"},
      {EXIT => 1},
     ],

     # From coreutils-5.3.0 to 8.22 inclusive
     # this would either infinite loop or crash
     ['invalid-TZ-crash', "-d 'TZ=\"\"\"'",
      {ERR => "date: invalid date 'TZ=\"\"\"'\n"},
      {EXIT => 1},
     ],

     # https://bugs.debian.org/851934#10
     ['cross-TZ-mishandled', "-d 'TZ=\"EST5\" 1970-01-01 00:00'",
      {ENV => 'TZ=PST8'},
      {OUT => 'Wed Dec 31 21:00:00 PST 1969'},
     ],
    );

# Repeat the cross-dst test, using Jan 1, 2005 and every interval from 1..364.
foreach my $i (1..364)
  {
    push @Tests, ["cross-dst$i",
                  "-d'2005-01-01 +$i day'", '+%Y', {OUT=>"2005"},
                  {ENV_DEL => 'TZ'},
                  ];
  }

# Append "\n" to each OUT=> RHS if the expected exit value is either
# zero or not specified (defaults to zero).
foreach my $t (@Tests)
  {
    my $exit_val;
    foreach my $e (@$t)
      {
        ref $e && ref $e eq 'HASH' && defined $e->{EXIT}
          and $exit_val = $e->{EXIT};
      }
    foreach my $e (@$t)
      {
        ref $e && ref $e eq 'HASH' && defined $e->{OUT} && ! $exit_val
          and $e->{OUT} .= "\n";
      }
  }

# Repeat all tests with --debug option, ensure it does not cause any regression
my @debug_tests;
foreach my $t (@Tests)
  {
    # Skip tests with EXIT!=0 or ERR_SUBST part
    # (as '--debug' requires its own ERR_SUBST).
    my $exit_val;
    my $have_err_subst;
    foreach my $e (@$t)
      {
        next unless ref $e && ref $e eq 'HASH';
        $exit_val = $e->{EXIT} if defined $e->{EXIT};
        $have_err_subst = 1 if defined $e->{ERR_SUBST};
      }
    next if $exit_val || $have_err_subst;

    # Duplicate the test, add '--debug' argument
    my @newt = @$t;
    $newt[0] = 'dbg_' . $newt[0];
    $newt[1] = '--debug ' . $newt[1];

    # Discard all debug printouts before comparing output
    push @newt, {ERR_SUBST => q!s/^date: .*\n//m!};

    push @debug_tests, \@newt;
  }
push @Tests, @debug_tests;


my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $prog = 'date';
my $fail = run_tests ($ME, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
