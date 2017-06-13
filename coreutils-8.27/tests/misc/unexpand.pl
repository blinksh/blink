#!/usr/bin/perl
# Test "unexpand".

# Copyright (C) 2000-2017 Free Software Foundation, Inc.

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

(my $program_name = $0) =~ s|.*/||;

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my $prog = 'unexpand';

my @Tests =
    (
     ['a1', {IN=> ' 'x 1 ."y\n"}, {OUT=> ' 'x 1 ."y\n"}],
     ['a2', {IN=> ' 'x 2 ."y\n"}, {OUT=> ' 'x 2 ."y\n"}],
     ['a3', {IN=> ' 'x 3 ."y\n"}, {OUT=> ' 'x 3 ."y\n"}],
     ['a4', {IN=> ' 'x 4 ."y\n"}, {OUT=> ' 'x 4 ."y\n"}],
     ['a5', {IN=> ' 'x 5 ."y\n"}, {OUT=> ' 'x 5 ."y\n"}],
     ['a6', {IN=> ' 'x 6 ."y\n"}, {OUT=> ' 'x 6 ."y\n"}],
     ['a7', {IN=> ' 'x 7 ."y\n"}, {OUT=> ' 'x 7 ."y\n"}],
     ['a8', {IN=> ' 'x 8 ."y\n"}, {OUT=> "\ty\n"}],

     ['aa-1', '-a', {IN=> 'w'.' 'x 1 ."y\n"}, {OUT=> 'w'.' 'x 1 ."y\n"}],
     ['aa-2', '-a', {IN=> 'w'.' 'x 2 ."y\n"}, {OUT=> 'w'.' 'x 2 ."y\n"}],
     ['aa-3', '-a', {IN=> 'w'.' 'x 3 ."y\n"}, {OUT=> 'w'.' 'x 3 ."y\n"}],
     ['aa-4', '-a', {IN=> 'w'.' 'x 4 ."y\n"}, {OUT=> 'w'.' 'x 4 ."y\n"}],
     ['aa-5', '-a', {IN=> 'w'.' 'x 5 ."y\n"}, {OUT=> 'w'.' 'x 5 ."y\n"}],
     ['aa-6', '-a', {IN=> 'w'.' 'x 6 ."y\n"}, {OUT=> 'w'.' 'x 6 ."y\n"}],
     ['aa-7', '-a', {IN=> 'w'.' 'x 7 ."y\n"}, {OUT=> "w\ty\n"}],
     ['aa-8', '-a', {IN=> 'w'.' 'x 8 ."y\n"}, {OUT=> "w\t y\n"}],

     ['b-1', '-t', '2,4', {IN=> "      ."}, {OUT=>"\t\t  ."}],
     # These would infloop prior to textutils-2.0d.

     ['infloop-1', '-t', '1,2', {IN=> " \t\t .\n"}, {OUT=>"\t\t\t .\n"}],
     ['infloop-2', '-t', '4,5', {IN=> ' 'x4 . "\t\t \n"}, {OUT=>"\t\t\t \n"}],
     ['infloop-3', '-t', '2,3', {IN=> "x \t\t \n"}, {OUT=>"x\t\t\t \n"}],
     ['infloop-4', '-t', '1,2', {IN=> " \t\t   \n"}, {OUT=>"\t\t\t   \n"}],
     ['c-1', '-t', '1,2', {IN=> "x\t\t .\n"}, {OUT=>"x\t\t .\n"}],

     # -t implies -a
     # Feature addition (--first-only) prompted by a report from Jie Xu.
     ['tabs-1', qw(-t 3),              {IN=> "   a  b\n"}, {OUT=>"\ta\tb\n"}],
     ['tabs-2', qw(-t 3 --first-only), {IN=> "   a  b\n"}, {OUT=>"\ta  b\n"}],

     # blanks
     ['blanks-1', qw(-t 1), {IN=> " b  c   d\n"}, {OUT=> "\tb\t\tc\t\t\td\n"}],
     ['blanks-2', qw(-t 1), {IN=> "a \n"}, {OUT=> "a \n"}],
     ['blanks-3', qw(-t 1), {IN=> "a  \n"}, {OUT=> "a\t\t\n"}],
     ['blanks-4', qw(-t 1), {IN=> "a   \n"}, {OUT=> "a\t\t\t\n"}],
     ['blanks-5', qw(-t 1), {IN=> "a "}, {OUT=> "a "}],
     ['blanks-6', qw(-t 1), {IN=> "a  "}, {OUT=> "a\t\t"}],
     ['blanks-7', qw(-t 1), {IN=> "a   "}, {OUT=> "a\t\t\t"}],
     ['blanks-8', qw(-t 1), {IN=> " a a  a\n"}, {OUT=> "\ta a\t\ta\n"}],
     ['blanks-9', qw(-t 2), {IN=> "   a  a  a\n"}, {OUT=> "\t a\ta\t a\n"}],
     ['blanks-10', '-t', '3,4', {IN=> "0 2 4 6\t8\n"}, {OUT=> "0 2 4 6\t8\n"}],
     ['blanks-11', '-t', '3,4', {IN=> "    4\n"}, {OUT=> "\t\t4\n"}],
     ['blanks-12', '-t', '3,4', {IN=> "01  4\n"}, {OUT=> "01\t\t4\n"}],
     ['blanks-13', '-t', '3,4', {IN=> "0   4\n"}, {OUT=> "0\t\t4\n"}],

     # POSIX says spaces should only follow tabs. Also a single
     # trailing space is not converted to a tab, when before
     # a field starting with non blanks
     ['posix-1', '-a', {IN=> "1234567   \t1\n"}, {OUT=>"1234567\t\t1\n"}],
     ['posix-2', '-a', {IN=> "1234567  \t1\n"},  {OUT=>"1234567\t\t1\n"}],
     ['posix-3', '-a', {IN=> "1234567 \t1\n"},   {OUT=>"1234567\t\t1\n"}],
     ['posix-4', '-a', {IN=> "1234567\t1\n"},    {OUT=>"1234567\t1\n"}],
     ['posix-5', '-a', {IN=> "1234567  1\n"},    {OUT=>"1234567\t 1\n"}],
     ['posix-6', '-a', {IN=> "1234567 1\n"},     {OUT=>"1234567 1\n"}],

     # It is debatable whether this test should require an environment
     # setting of e.g., _POSIX2_VERSION=1.
     ['obs-ovflo', "-$limits->{UINTMAX_OFLOW}", {IN=>''}, {OUT=>''},
      {EXIT => 1}, {ERR => "$prog: tab stop value is too large\n"}],


     # Test input with backspaces '\b' ('bs1' is the baseline, without \b)
     # Note: If users report errors in these tests, copy&pasting results from
     # their terminate output might be confusing due to '\b' overriding
     # characters. For details see '\b' tests in 'expand.pl'.
     ['bs1', '-a -t4', {IN=>"aa  c\n"},    {OUT=>"aa\tc\n"}],
     ['bs2', '-a -t4', {IN=>"aa\b  c\n"},  {OUT=>"aa\b  c\n"}],
     ['bs3', '-a -t4', {IN=>"aa\b   c\n"}, {OUT=>"aa\b\tc\n"}],
     ['bs4', '-a -t3', {IN=>"aa\b  c\n"},  {OUT=>"aa\b\tc\n"}],

     # Undocumented feature:
     #   treat "unexpand -7"  as "unexpand --first-only --tabs 7" ,
     #   and   "unexpand -90" as "unexpand --first-only --tabs 90",
     ['u1', '-a -3',    {IN=>"a  b  c"}, {OUT=>"a\tb\tc"}],
     ['u2', '-a -4,9',  {IN=>"a   b    c"}, {OUT=>"a\tb\tc"}],
     ['u3', '-a -11',   {IN=>"a          b"}, {OUT=>"a\tb"}],
     # Test all digits (for full code coverage)
     ['u4', '-a -2,6',  {IN=>"a b   c"}, {OUT=>"a b\tc"}],
     ['u5', '-a -7',    {IN=>"a      b"},    {OUT=>"a\tb"}],
     ['u6', '-a -8',    {IN=>"a       b"},    {OUT=>"a\tb"}],
     # This syntax is handled internally as "-3, -9"
     ['u7', '-a -3,9',  {IN=>"a  b     c"}, {OUT=>"a\tb\tc"}],
     # Default (without -a) is --first-only:
     ['u8', '-3',  {IN=>"   a   b"}, {OUT=>"\ta   b"}],

     # Arguably this should minimize translation as is done on Solaris.
     # I.e., not modify the input.  But since the result is equivalent,
     # and to be consistent in output with older versions, we output
     # a '\t' rather than a space for the second tab position.
     # For more detailed comparison with other implementations see:
     # http://lists.gnu.org/archive/html/coreutils/2016-06/msg00015.html
     # http://lists.gnu.org/archive/html/coreutils/2016-07/msg00011.html
     ['ts1', '-t8,9', {IN=>"x\t \t y\n"},    {OUT=>"x\t\t\t y\n"}],
     # There is no ambiguity here. This should always be the output.
     ['ts2', '-t5,8', {IN=>"x\t \t y\n"},    {OUT=>"x\t\t y\n"}],
    );

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
