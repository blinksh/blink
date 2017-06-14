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
use POSIX qw(strftime);

(my $ME = $0) =~ s|.*/||;

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

# Export TZ=UTC0 so that zone-dependent strings match.
$ENV{TZ} = 'UTC0';

my $now = time;
my @d = localtime ($now);
my @d_week = localtime ($now + 7 * 24 * 3600);
my $wday = $d[6];
my $wday_str = qw(sun mon tue wed thu fri sat)[$wday];

my @Tests =
    (
     # test-name, [option, option, ...] {OUT=>"expected-output"}
     #

     # Running "date -d mon +%a" on a Monday must print Mon.
     ['dow',  "-d $wday_str +%a", {OUT => ucfirst $wday_str}],
     # It had better be the same date, too.
     ['dow2', "-d $wday_str +%Y-%m-%d", {OUT => strftime("%Y-%m-%d", @d)}],

     ['next-dow', "-d 'next $wday_str' +%Y-%m-%d",
      {OUT => strftime("%Y-%m-%d", @d_week)}],
    );

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

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $prog = 'date';
my $fail = run_tests ($ME, $prog, \@Tests, $save_temps, $verbose);

# Skip the test if the starting and stopping day numbers differ.
my @d_post = localtime (time);
$d_post[7] == $d[7]
  or CuSkip::skip "$ME: test straddled a day boundary; skipped";

exit $fail;
