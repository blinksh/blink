#!/usr/bin/perl
# -*- perl -*-
# Test comm

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

require 5.003;
use strict;

(my $program_name = $0) =~ s|.*/||;

my $prog = 'comm';

# Turn off localization of executable's ouput.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my @inputs = ({IN=>{a=>"1\n3\n3\n3"}}, {IN=>{b=>"2\n2\n3\n3\n3"}});
my @zinputs = ({IN=>{za=>"1\0003\0003\0003"}},
               {IN=>{zb=>"2\0002\0003\0003\0003"}});

my @Tests =
  (
   # basic operation
   ['basic', @inputs, {OUT=>"1\n\t2\n\t2\n\t\t3\n\t\t3\n\t\t3\n"} ],
   ['zbasic', '-z', @zinputs, {OUT=>"1\0\t2\0\t2\0\t\t3\0\t\t3\0\t\t3\0"} ],

   # suppress lines unique to file 1
   ['opt-1', '-1', @inputs, {OUT=>"2\n2\n\t3\n\t3\n\t3\n"} ],
   ['zopt-1', '-z', '-1', @zinputs, {OUT=>"2\0002\000\t3\000\t3\000\t3\000"} ],

   # suppress lines unique to file 2
   ['opt-2', '-2', @inputs, {OUT=>"1\n\t3\n\t3\n\t3\n"} ],
   ['zopt-2', '-z', '-2', @zinputs, {OUT=>"1\000\t3\000\t3\000\t3\000"} ],

   # suppress lines that appear in both files
   ['opt-3', '-3', @inputs, {OUT=>"1\n\t2\n\t2\n"} ],
   ['zopt-3', '-z', '-3', @zinputs, {OUT=>"1\000\t2\000\t2\000"} ],

   # suppress lines unique to file 1 and lines unique to file 2
   ['opt-12', '-1', '-2', @inputs, {OUT=>"3\n3\n3\n"} ],
   ['zopt-12', '-12z', @zinputs, {OUT=>"3\0003\0003\000"} ],

   # suppress lines unique to file 1 and those that appear in both files
   ['opt-13', '-1', '-3', @inputs, {OUT=>"2\n2\n"} ],
   ['zopt-13', '-13z', @zinputs, {OUT=>"2\0002\000"} ],

   # suppress lines unique to file 2 and those that appear in both files
   ['opt-23', '-2', '-3', @inputs, {OUT=>"1\n"} ],
   ['zopt-23', '-23z', @zinputs, {OUT=>"1\000"} ],

   # suppress all output
   ['opt-123', '-1', '-2', '-3', @inputs, {OUT=>""} ],

   # show summary: 1 only in file1, 2 only in file2, 3 in both files
   ['total-all', '--total', @inputs, {OUT=>"1\n\t2\n\t2\n\t\t3\n\t\t3\n\t\t3\n"
     . "1\t2\t3\ttotal\n"} ],

   # show summary only, suppressing regular output
   ['total-123', '--total', '-123', @inputs, {OUT=>"1\t2\t3\ttotal\n"} ],

   # invalid missing command line argument (1)
   ['missing-arg1', $inputs[0], {EXIT=>1},
    {ERR => "$prog: missing operand after 'a'\n"
        . "Try '$prog --help' for more information.\n"}],

   # invalid missing command line argument (both)
   ['missing-arg2', {EXIT=>1},
    {ERR => "$prog: missing operand\n"
        . "Try '$prog --help' for more information.\n"}],

   # invalid extra command line argument
   ['extra-arg', @inputs, 'no-such', {EXIT=>1},
    {ERR => "$prog: extra operand 'no-such'\n"
        . "Try '$prog --help' for more information.\n"}],

   # out-of-order input
   ['ooo', {IN=>{a=>"1\n3"}}, {IN=>{b=>"3\n2"}}, {EXIT=>1},
    {OUT => "1\n\t\t3\n\t2\n"},
    {ERR => "$prog: file 2 is not in sorted order\n"}],

   # out-of-order input, fatal
   ['ooo2', '--check-order', {IN=>{a=>"1\n3"}}, {IN=>{b=>"3\n2"}}, {EXIT=>1},
    {OUT => "1\n\t\t3\n"},
    {ERR => "$prog: file 2 is not in sorted order\n"}],

   # out-of-order input, ignored
   ['ooo3', '--nocheck-order', {IN=>{a=>"1\n3"}}, {IN=>{b=>"3\n2"}},
    {OUT => "1\n\t\t3\n\t2\n"}],

   # both inputs out-of-order
   ['ooo4', {IN=>{a=>"3\n1\n0"}}, {IN=>{b=>"3\n2\n0"}}, {EXIT=>1},
    {OUT => "\t\t3\n1\n0\n\t2\n\t0\n"},
    {ERR => "$prog: file 1 is not in sorted order\n".
            "$prog: file 2 is not in sorted order\n" }],

   # both inputs out-of-order on last pair
   ['ooo5', {IN=>{a=>"3\n1"}}, {IN=>{b=>"3\n2"}}, {EXIT=>1},
    {OUT => "\t\t3\n1\n\t2\n"},
    {ERR => "$prog: file 1 is not in sorted order\n".
            "$prog: file 2 is not in sorted order\n" }],

   # first input out-of-order extended
   ['ooo5b', {IN=>{a=>"0\n3\n1"}}, {IN=>{b=>"2\n3"}}, {EXIT=>1},
    {OUT => "0\n\t2\n\t\t3\n1\n"},
    {ERR => "$prog: file 1 is not in sorted order\n"}],

   # second input out-of-order extended
   ['ooo5c', {IN=>{a=>"0\n3"}}, {IN=>{b=>"2\n3\n1"}}, {EXIT=>1},
    {OUT => "0\n\t2\n\t\t3\n\t1\n"},
    {ERR => "$prog: file 2 is not in sorted order\n"}],

   # both inputs out-of-order, but fully pairable
   ['ooo6', {IN=>{a=>"2\n1\n0"}}, {IN=>{b=>"2\n1\n0"}}, {EXIT=>0},
    {OUT => "\t\t2\n\t\t1\n\t\t0\n"}],

   # both inputs out-of-order, fully pairable, but forced to fail
   ['ooo7', '--check-order', {IN=>{a=>"2\n1\n0"}}, {IN=>{b=>"2\n1\n0"}},
    {EXIT=>1},
    {OUT => "\t\t2\n"},
    {ERR => "$prog: file 1 is not in sorted order\n"}],

   # out-of-order, line 2 is a prefix of line 1
   # until coreutils-7.2, this test would fail -- no disorder detected
   ['ooo-prefix', '--check-order', {IN=>{a=>"Xa\nX\n"}}, {IN=>{b=>""}},
    {EXIT=>1},
    {OUT => "Xa\n"},
    {ERR => "$prog: file 1 is not in sorted order\n"}],

   # alternate delimiter: ','
   ['delim-comma', '--output-delimiter=,', @inputs,
    {OUT=>"1\n,2\n,2\n,,3\n,,3\n,,3\n"} ],

   # two-character alternate delimiter: '++'
   ['delim-2char', '--output-delimiter=++', @inputs,
    {OUT=>"1\n++2\n++2\n++++3\n++++3\n++++3\n"} ],

   # NUL delimiter
   ['delim-empty', '--output-delimiter=', @inputs,
    {OUT=>"1\n\0002\n\0002\n\000\0003\n\000\0003\n\000\0003\n"} ],
   ['zdelim-empty', '-z', '-z --output-delimiter=', @zinputs,
    {OUT=>"1\000\0002\000\0002\000\000\0003\000\000\0003\000\000\0003\000"} ],

   # invalid dual delimiter
   ['delim-dual', '--output-delimiter=,', '--output-delimiter=+', @inputs,
    {EXIT=>1}, {ERR => "$prog: multiple output delimiters specified\n"}],

   # valid dual delimiter specification
   ['delim-dual2', '--output-delimiter=,', '--output-delimiter=,', @inputs,
    {OUT=>"1\n,2\n,2\n,,3\n,,3\n,,3\n"} ],

   # show summary, zero-terminated
   ['totalz-all', '--total', '-z', @zinputs,
    {OUT=>"1\000\t2\000\t2\000\t\t3\000\t\t3\000\t\t3\000"
        . "1\t2\t3\ttotal\000"} ],

   # show summary only (-123), zero-terminated and with ',' as delimiter
   ['totalz-123', '--total', '-z123', '--output-delimiter=,', @zinputs,
    {OUT=>"1,2,3,total\000"} ],
 );

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
