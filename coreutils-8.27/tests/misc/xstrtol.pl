#!/usr/bin/perl
# exercise xstrtol's diagnostics via pr

# Copyright (C) 2007-2017 Free Software Foundation, Inc.

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

my $prog = 'pr';
my $too_big = '9' x 81; # Big enough to overflow a 256-bit integer.
my @Tests =
  (
   # test-name, [option, option, ...] {OUT=>"expected-output"}

   ['inval-suffix', "--pages=${too_big}h", {EXIT => 1},
    {ERR=>"$prog: invalid suffix in --pages argument '${too_big}h'\n"}],

   ['too-big', "--pages=$too_big", {EXIT => 1},
    {ERR=>"$prog: --pages argument '$too_big' too large\n"}],

   ['simply-inval', "--pages=x", {EXIT => 1},
    {ERR=>"$prog: invalid --pages argument 'x'\n"}],

   ['inv-pg-range', "--pages=9x", {EXIT => 1},
    {ERR=>"$prog: invalid page range '9x'\n"}],
  );

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($ME, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
