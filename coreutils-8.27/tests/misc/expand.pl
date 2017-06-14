#!/usr/bin/perl
# Exercise expand.

# Copyright (C) 2004-2017 Free Software Foundation, Inc.

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

my $limits = getlimits ();
my $UINTMAX_OFLOW = $limits->{UINTMAX_OFLOW};

(my $program_name = $0) =~ s|.*/||;
my $prog = 'expand';

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my @Tests =
  (
   ['t1', '--tabs=3',     {IN=>"a\tb"}, {OUT=>"a  b"}],
   ['t2', '--tabs=3,6,9', {IN=>"a\tb\tc\td\te"}, {OUT=>"a  b  c  d e"}],
   ['t3', '--tabs="3 6 9"',   {IN=>"a\tb\tc\td\te"}, {OUT=>"a  b  c  d e"}],
   # Leading space/commas are silently ignored; Mixing space/commas is allowed.
   # (a side-effect of allowing direct "-3,9" parameter).
   ['t4', '--tabs=", 3,6 9"', {IN=>"a\tb\tc\td\te"}, {OUT=>"a  b  c  d e"}],
   # tab stops parameter without values
   ['t5', '--tabs=""',        {IN=>"a\tb\tc"}, {OUT=>"a       b       c"}],
   ['t6', '--tabs=","',       {IN=>"a\tb\tc"}, {OUT=>"a       b       c"}],
   ['t7', '--tabs=" "',       {IN=>"a\tb\tc"}, {OUT=>"a       b       c"}],
   ['t8', '--tabs="/"',       {IN=>"a\tb\tc"}, {OUT=>"a       b       c"}],

   # Input field wider than the specified tab list
   ['if', '--tabs=6,9', {IN=>"a\tbbbbbbbbbbbbb\tc"},
    {OUT=>"a     bbbbbbbbbbbbb c"}],

   ['i1', '--tabs=3 -i', {IN=>"\ta\tb"}, {OUT=>"   a\tb"}],
   ['i2', '--tabs=3 -i', {IN=>" \ta\tb"}, {OUT=>"   a\tb"}],

   # Undocumented feature:
   #   treat "expand -7"  as "expand --tabs 7" ,
   #   and   "expand -90" as "expand --tabs 90",
   ['u1', '-3',    {IN=>"a\tb\tc"}, {OUT=>"a  b  c"}],
   ['u2', '-4 -9', {IN=>"a\tb\tc"}, {OUT=>"a   b    c"}],
   ['u3', '-11',   {IN=>"a\tb\tc"}, {OUT=>"a          b          c"}],
   # Test all digits (for full code coverage)
   ['u4', '-2 -6', {IN=>"a\tb\tc"}, {OUT=>"a b   c"}],
   ['u5', '-7',    {IN=>"a\tb"},    {OUT=>"a      b"}],
   ['u6', '-8',    {IN=>"a\tb"},    {OUT=>"a       b"}],
   # This syntax is handled internally as "-3, -9"
   ['u7', '-3,9',  {IN=>"a\tb\tc"}, {OUT=>"a  b     c"}],

   # Multiple non-empty files
   ['f1', '--tabs=4',
    {IN=>{"in1" => "a\tb\n"}}, {IN=>{"in2" => "c\td\n"}},
    {OUT=>"a   b\nc   d\n"}],
   # Multiple files, first file is empty
   ['f2', '--tabs=4',
    {IN=>{"in1" => ""}}, {IN=>{"in2" => "c\td\n"}},
    {OUT=>"c   d\n"}],
   # Multiple files, second file is empty
   ['f3', '--tabs=4',
    {IN=>{"in1" => "a\tb\n"}}, {IN=>{"in2" => ""}},
    {OUT=>"a   b\n"}],


   # Test '\b' (back-space) - subtract one column.
   #
   # Note:
   # In a terminal window, 'expand' will appear to erase the 'a' characters
   # due to overwriting them with spaces:
   #
   #    $ printf 'aaa\b\b\bc\td\n'
   #    caa     d
   #    $ printf 'aaa\b\b\bc\td\n' | expand
   #    c       d
   #
   # However the characters are all printed:
   #
   #    $ printf 'aaa\b\b\bc\td\n' | expand | od -An -ta
   #      a   a   a  bs  bs  bs   c  sp  sp  sp  sp  sp  sp  sp   d  nl
   #
   # If users ever report a problem with these tests and just
   # copy&paste from the terminal, their report will be confusing
   # (the 'a' will not appear).
   #
   # To see an example, enable the 'b-confusing' test, and examine the
   # reported log:
   #
   #     expand.pl: test b-confusing: stdout mismatch
   #     *** b-confusing.2       Fri Jun 24 15:43:21 2016
   #     --- b-confusing.O       Fri Jun 24 15:43:21 2016
   #     ***************
   #     *** 1 ****
   #     ! c       d
   #     --- 1 ----
   #     ! c       d
   #
   # ['b-confusing','', {IN=>"aaa\b\b\bc\td\n"}, {OUT=>"c       d\n"}],

   ['b1','', {IN=>"aaa\b\b\bc\td\n"}, {OUT=>"aaa\b\b\bc       d\n"}],

   # \b as first character, when column is zero
   ['b2','', {IN=>"\bc\td"}, {OUT=>"\bc       d"}],

   # Testing tab list adjusted due to backspaces
   # ('b3' is the baseline without backspaces).
   ['b3','--tabs 2,4,6,10',
    {IN=>"1\t2\t3\t4\t5\n" .
         "a\tb\tc\td\te\n"},
    {OUT=>"1 2 3 4   5\n" .
          "a b c d   e\n"}],

   # On screen this will appear the same as 'b3'
   ['b4','--tabs 2,4,6,10',
    {IN=>"1\t2\t3\t4\t5\n" .
         "a\tbHELLO\b\b\b\b\b\tc\td\te\n"},
    {OUT=>"1 2 3 4   5\n" .
          "a bHELLO\b\b\b\b\b c d   e\n"}],

   # On screen on 'bHE' will appear (LLO overwritten by spaces),
   # 'c' should align with 4, 'd' with 5:
   #   1 2 3 4   5
   #   a bHE c   d e
   ['b5','--tabs 2,4,6,10',
    {IN=>"1\t2\t3\t4\t5\n" .
         "a\tbHELLO\b\b\b\tc\td\te\n"},
    {OUT=>"1 2 3 4   5\n" .
          "a bHELLO\b\b\b c   d e\n"}],

   # Test the trailing '/' feature which specifies the
   # tab size to use after the last specified stop
   ['trail1', '--tabs=1,/5',   {IN=>"\ta\tb\tc"}, {OUT=>" a   b    c"}],
   ['trail2', '--tabs=2,/5',   {IN=>"\ta\tb\tc"}, {OUT=>"  a  b    c"}],
   ['trail3', '--tabs=1,2,/5', {IN=>"\ta\tb\tc"}, {OUT=>" a   b    c"}],
   ['trail4', '--tabs=/5',     {IN=>"\ta\tb"},    {OUT=>"     a    b"}],
   ['trail5', '--tabs=//5',    {IN=>"\ta\tb"},    {OUT=>"     a    b"}],
   ['trail6', '--tabs=/,/5',   {IN=>"\ta\tb"},    {OUT=>"     a    b"}],
   ['trail7', '--tabs=,/5',    {IN=>"\ta\tb"},    {OUT=>"     a    b"}],
   ['trail8', '--tabs=1 -t/5', {IN=>"\ta\tb\tc"}, {OUT=>" a   b    c"}],
   ['trail9', '--tab=1,2 -t/5',{IN=>"\ta\tb\tc"}, {OUT=>" a   b    c"}],

   # Test errors
   ['e1', '--tabs="a"', {IN=>''}, {OUT=>''}, {EXIT=>1},
    {ERR => "$prog: tab size contains invalid character(s): 'a'\n"}],
   ['e2', "-t $UINTMAX_OFLOW", {IN=>''}, {OUT=>''}, {EXIT=>1},
    {ERR => "$prog: tab stop is too large '$UINTMAX_OFLOW'\n"}],
   ['e3', '--tabs=0',   {IN=>''}, {OUT=>''}, {EXIT=>1},
    {ERR => "$prog: tab size cannot be 0\n"}],
   ['e4', '--tabs=3,3', {IN=>''}, {OUT=>''}, {EXIT=>1},
    {ERR => "$prog: tab sizes must be ascending\n"}],
   ['e5', '--tabs=/3,6,8', {IN=>''}, {OUT=>''}, {EXIT=>1},
    {ERR => "$prog: '/' specifier only allowed with the last value\n"}],
   ['e6', '-t/3 -t/6', {IN=>''}, {OUT=>''}, {EXIT=>1},
    {ERR => "$prog: '/' specifier only allowed with the last value\n"}],
   ['e7', '--tabs=3/', {IN=>''}, {OUT=>''}, {EXIT=>1},
    {ERR => "$prog: '/' specifier not at start of number: '/'\n"}],
  );

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
