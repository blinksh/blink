#!/usr/bin/perl
# Basic tests for "wc".

# Copyright (C) 1997-2017 Free Software Foundation, Inc.

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

my $prog = 'wc';

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my @Tests =
    (
     ['a0', '-c',  {IN_PIPE=>''},            {OUT=>"0\n"}],
     ['a1', '-l',  {IN_PIPE=>''},            {OUT=>"0\n"}],
     ['a2', '-w',  {IN_PIPE=>''},            {OUT=>"0\n"}],
     ['a3', '-c',  {IN_PIPE=>'x'},           {OUT=>"1\n"}],
     ['a4', '-w',  {IN_PIPE=>'x'},           {OUT=>"1\n"}],
     ['a5', '-w',  {IN_PIPE=>"x y\n"},       {OUT=>"2\n"}],
     ['a6', '-w',  {IN_PIPE=>"x y\nz"},      {OUT=>"3\n"}],
     # Remember, -l counts *newline* bytes, not logical lines.
     ['a7', '-l',  {IN_PIPE=>"x y"},         {OUT=>"0\n"}],
     ['a8', '-l',  {IN_PIPE=>"x y\n"},       {OUT=>"1\n"}],
     ['a9', '-l',  {IN_PIPE=>"x\ny\n"},      {OUT=>"2\n"}],
     ['b0', '',    {IN_PIPE=>""},         {OUT=>"      0       0       0\n"}],
     ['b1', '',    {IN_PIPE=>"a b\nc\n"}, {OUT=>"      2       3       6\n"}],
     ['c0', '-L',  {IN_PIPE=>"1\n12\n"},     {OUT=>"2\n"}],
     ['c1', '-L',  {IN_PIPE=>"1\n123\n1\n"}, {OUT=>"3\n"}],
     ['c2', '-L',  {IN_PIPE=>"\n123456"},    {OUT=>"6\n"}],
    );

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($prog, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
