#!/usr/bin/perl

# Copyright (C) 2008-2017 Free Software Foundation, Inc.

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

my $prog = 'ptx';

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my @Tests =
(
["1tok", '-w10', {IN=>"bar\n"},     {OUT=>"        bar\n"}],
["2tok", '-w10', {IN=>"foo bar\n"}, {OUT=>"     /   bar\n        foo/\n"}],

# with coreutils-6.12 and earlier, this would infloop with -wN, N < 10
["narrow", '-w2', {IN=>"qux\n"},    {OUT=>"      qux\n"}],
["narrow-g", '-g1 -w2', {IN=>"ta\n"}, {OUT=>"  ta\n"}],

# with coreutils-6.12 and earlier, this would act like "ptx F1 F1"
["2files", '-g1 -w1', {IN=>{F1=>"a"}}, {IN=>{F2=>"b"}}, {OUT=>"  a\n  b\n"}],

# with coreutils-8.22 and earlier, the --format long option would
# fall through into the --help case.
["format-r", '--format=roff', {IN=>"foo\n"},
                              {OUT=>".xx \"\" \"\" \"foo\" \"\"\n"}],
["format-t", '--format=tex',  {IN=>"foo\n"},
                              {OUT=>"\\xx {}{}{foo}{}{}\n"}],
);

@Tests = triple_test \@Tests;

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($prog, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
