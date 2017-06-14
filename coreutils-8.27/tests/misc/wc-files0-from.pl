#!/usr/bin/perl
# Exercise wc's --files0-from option.
# FIXME: keep this file in sync with tests/du/files0-from.

# Copyright (C) 2006-2017 Free Software Foundation, Inc.

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

(my $program_name = $0) =~ s|.*/||;

my $prog = 'wc';

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my @Tests =
  (
   # invalid extra command line argument
   ['f-extra-arg', '--files0-from=- no-such', {IN=>"a"}, {EXIT=>1},
    {ERR => "$prog: extra operand 'no-such'\n"
        . "file operands cannot be combined with --files0-from\n"
        . "Try '$prog --help' for more information.\n"}
    ],

   # missing input file
   ['missing', '--files0-from=missing', {EXIT=>1},
    {ERR => "$prog: cannot open 'missing' for reading: "
     . "No such file or directory\n"}],

   # input file name of '-'
   ['minus-in-stdin', '--files0-from=-', '<', {IN=>{f=>'-'}}, {EXIT=>1},
    {ERR => "$prog: when reading file names from stdin, no file name of"
     . " '-' allowed\n"}],

   # empty input, regular file
   ['empty', '--files0-from=@AUX@', {AUX=>''}],

   # empty input, from non-regular file
   ['empty-nonreg', '--files0-from=/dev/null'],

   # one NUL
   ['nul-1', '--files0-from=-', '<', {IN=>"\0"}, {EXIT=>1},
    {ERR => "$prog: -:1: invalid zero-length file name\n"}],

   # two NULs
   ['nul-2', '--files0-from=-', '<', {IN=>"\0\0"}, {EXIT=>1},
    {OUT=>"0 0 0 total\n"},
    {ERR => "$prog: -:1: invalid zero-length file name\n"
          . "$prog: -:2: invalid zero-length file name\n"}],

   # one file name, no NUL
   ['1', '--files0-from=-', '<',
    {IN=>{f=>"g"}}, {AUX=>{g=>''}}, {OUT=>"0 0 0 g\n"} ],

   # one file name, with NUL
   ['1a', '--files0-from=-', '<',
    {IN=>{f=>"g\0"}}, {AUX=>{g=>''}}, {OUT=>"0 0 0 g\n"} ],

   # two file names, no final NUL
   ['2', '--files0-from=-', '<',
    {IN=>{f=>"g\0g"}}, {AUX=>{g=>''}},
     {OUT=>"0 0 0 g\n0 0 0 g\n0 0 0 total\n"} ],

   # two file names, with final NUL
   ['2a', '--files0-from=-', '<',
    {IN=>{f=>"g\0g\0"}}, {AUX=>{g=>''}},
     {OUT=>"0 0 0 g\n0 0 0 g\n0 0 0 total\n"} ],

   # Ensure that $prog processes FILEs following a zero-length name.
   ['zero-len', '--files0-from=-', '<',
    {IN=>{f=>"\0g\0"}}, {AUX=>{g=>''}},
    {OUT=>"0 0 0 g\n0 0 0 total\n"},
    {ERR => "$prog: -:1: invalid zero-length file name\n"}, {EXIT=>1} ],
  );

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
