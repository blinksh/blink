#!/usr/bin/perl
# Test "seq".

# Copyright (C) 1999-2017 Free Software Foundation, Inc.

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

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my $prog = 'seq';
my $try_help = "Try '$prog --help' for more information.\n";
my $err_inc_zero = "seq: invalid Zero increment value: '0'\n".$try_help;
my $err_nan_arg = "seq: invalid 'not-a-number' argument: 'nan'\n".$try_help;

my $locale = $ENV{LOCALE_FR_UTF8};
! defined $locale || $locale eq 'none'
  and $locale = 'C';

my $p = '9' x 81;
(my $q = $p) =~ s/9/0/g;
$q = "1$q";
(my $r = $q) =~ s/0$/1/;

my @Tests =
  (
   ['onearg-1',	qw(10),		{OUT => [(1..10)]}],
   ['onearg-2',	qw(-1)],
   ['empty-rev', qw(1 -1 3)],
   ['neg-1',	qw(-10 10 10),	{OUT => [qw(-10 0 10)]}],
   # ['neg-2',	qw(-.1 .1 .11),	{OUT => [qw(-0.1 0.0 0.1)]}],
   ['neg-3',	qw(1 -1 0),	{OUT => [qw(1 0)]}],
   ['neg-4',	qw(1 -1 -1),	{OUT => [qw(1 0 -1)]}],

   ['float-1',	qw(0.8 0.1 0.9),	{OUT => [qw(0.8 0.9)]}],
   ['float-2',	qw(0.1 0.99 1.99),	{OUT => [qw(0.10 1.09)]}],
   ['float-3',	qw(10.8 0.1 10.95),	{OUT => [qw(10.8 10.9)]}],
   ['float-4',	qw(0.1 -0.1 -0.2),	{OUT => [qw(0.1 0.0 -0.1 -0.2)]},
    {OUT_SUBST => 's,^-0\.0$,0.0,'},
   ],
   ['float-5',	qw(0.8 1e-1 0.9),	{OUT => [qw(0.8 0.9)]}],
   # Don't append lots of zeros to that 0.9000...; for example, changing the
   # number to 0.90000000000000000000 tickles a bug in Solaris 8 strtold
   # that would cause the test to fail.
   ['float-6',	qw(0.8 0.1 0.9000000000000),	{OUT => [qw(0.8 0.9)]}],

   ['wid-1',	qw(.8 1e-2 .81),  {OUT => [qw(0.80 0.81)]}],
   ['wid-2',	qw(.89999 1e-7 .8999901),  {OUT => [qw(0.8999900 0.8999901)]}],

   ['eq-wid-1',	qw(-w 1 -1 -1),	{OUT => [qw(01 00 -1)]}],
   # Prior to 2.0g, this test would fail on e.g., HPUX systems
   # because it'd end up using %3.1f as the format instead of %4.1f.
   ['eq-wid-2',	qw(-w -.1 .1 .11),{OUT => [qw(-0.1 00.0 00.1)]}],
   ['eq-wid-3',	qw(-w 1 3.0),  {OUT => [qw(1 2 3)]}],
   ['eq-wid-4',	qw(-w .8 1e-2 .81),  {OUT => [qw(0.80 0.81)]}],
   ['eq-wid-5',	qw(-w 1 .5 2),  {OUT => [qw(1.0 1.5 2.0)]}],
   ['eq-wid-6',	qw(-w +1 2),  {OUT => [qw(1 2)]}],
   ['eq-wid-7',	qw(-w "    .1"  "    .1"),  {OUT => [qw(0.1)]}],
   ['eq-wid-8',	qw(-w 9 0.5 10),  {OUT => [qw(09.0 09.5 10.0)]}],
   # Prior to 8.21, these tests involving numbers in scentific notation
   # would fail with misalignment or wrong widths.
   ['eq-wid-9',	qw(-w -1e-3 1),  {OUT => [qw(-0.001 00.999)]}],
   ['eq-wid-10',qw(-w -1e-003 1),  {OUT => [qw(-0.001 00.999)]}],
   ['eq-wid-11',qw(-w -1.e-3 1),  {OUT => [qw(-0.001 00.999)]}],
   ['eq-wid-12',qw(-w -1.0e-4 1),  {OUT => [qw(-0.00010 00.99990)]}],
   ['eq-wid-13',qw(-w 999 1e3),  {OUT => [qw(0999 1000)]}],
   # Prior to 8.21, if the start value hadn't a precision, while step did,
   # then misalignment would occur if the sequence narrowed.
   ['eq-wid-14',qw(-w -1 1.0 0),  {OUT => [qw(-1.0 00.0)]}],
   ['eq-wid-15',qw(-w 10 -.1 9.9),  {OUT => [qw(10.0 09.9)]}],

   # Prior to coreutils-4.5.11, some of these were not accepted.
   ['fmt-1',	qw(-f %2.1f 1.5 .5 2),{OUT => [qw(1.5 2.0)]}],
   ['fmt-2',	qw(-f %0.1f 1.5 .5 2),{OUT => [qw(1.5 2.0)]}],
   ['fmt-3',	qw(-f %.1f  1.5 .5 2),{OUT => [qw(1.5 2.0)]}],

   ['fmt-4',	qw(-f %3.0f 1 2),     {OUT => ['  1', '  2']}],
   ['fmt-5',	qw(-f %-3.0f 1 2),    {OUT => ['1  ', '2  ']}],
   ['fmt-6',	qw(-f %+3.0f 1 2),    {OUT => [' +1', ' +2']}],
   ['fmt-7',	qw(-f %0+3.0f 1 2),   {OUT => [qw(+01 +02)]}],
   ['fmt-8',	qw(-f %0+.0f 1 2),    {OUT => [qw(+1 +2)]}],
   ['fmt-9',	'-f "% -3.0f"', qw(-1 0), {OUT => ['-1 ', ' 0 ']}],
   ['fmt-a',	'-f "% -.0f"',qw(-1 0), {OUT => ['-1', ' 0']}],
   ['fmt-b',	qw(-f %%%g%% 1),	{OUT => ['%1%']}],

   # In coreutils-[6.0..6.9], this would mistakenly succeed and print "%Lg".
   ['fmt-c',	qw(-f %%g 1), {EXIT => 1},
    {ERR => "seq: format '%%g' has no % directive\n"}],

   # In coreutils-6.9..6.10, this would fail with an erroneous diagnostic:
   # "seq: memory exhausted".  In coreutils-6.0..6.8, it would mistakenly
   # succeed and print a blank line.
   ['fmt-eos1', qw(-f % 1), {EXIT => 1},
    {ERR => "seq: format '%' ends in %\n"}],
   ['fmt-eos2', qw(-f %g% 1), {EXIT => 1},
    {ERR => "seq: format '%g%' has too many % directives\n"}],

   ['fmt-d',	qw(-f "" 1), {EXIT => 1},
    {ERR => "seq: format '' has no % directive\n"}],
   ['fmt-e',	qw(-f %g%g 1), {EXIT => 1},
    {ERR => "seq: format '%g%g' has too many % directives\n"}],

   # With coreutils-6.12 and earlier, with a UTF8 numeric locale that uses
   # something other than "." as the decimal point, this use of seq would
   # fail to print the "2,0" endpoint.
   ['locale-dec-pt', qw(-0.1 0.1 2),
    {OUT => [qw(-0.1 0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0
                         1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0)]},

    {ENV => "LC_ALL=$locale"},
    {OUT_SUBST => 's/,/./g'},
    ],

   # With coreutils-8.19 and prior, this would infloop.
   ['long-1', "$p $r", {OUT => [$p, $q, $r]}],

   # Exercise the code that trims leading zeros.
   ['long-leading-zeros1', qw(000 2), {OUT => [qw(0 1 2)]}],
   ['long-leading-zeros2', qw(000 02), {OUT => [qw(0 1 2)]}],
   ['long-leading-zeros3', qw(00 02), {OUT => [qw(0 1 2)]}],
   ['long-leading-zeros4', qw(0 02), {OUT => [qw(0 1 2)]}],

   # Exercise the -s option, which was broken in 8.20
   ['sep-1', qw(-s, 1 3), {OUT => [qw(1,2,3)]}],
   ['sep-2', qw(-s, 1 1), {OUT => [qw(1)]}],
   ['sep-3', qw(-s,, 1 3), {OUT => [qw(1,,2,,3)]}],

   # Exercise fast path avoidance logic.
   # In 8.20 a step value != 1, with positive integer start and end was broken
   ['not-fast-1', qw(1 3 1), {OUT => [qw(1)]}],
   ['not-fast-2', qw(1 1 4.2), {OUT => [qw(1 2 3 4)]}],
   ['not-fast-3', qw(1 1 0)],
   # In 8.20..8.22 a start or end of -0 was broken
   ['not-fast-4', qw(-0 10), {OUT => [qw(-0 1 2 3 4 5 6 7 8 9 10)]}],
   ['not-fast-5', qw(1 -0)],

   # Ensure the correct parameters are passed to the fast path
   ['fast-1', qw(4), {OUT => [qw(1 2 3 4)]}],
   ['fast-2', qw(1 4), {OUT => [qw(1 2 3 4)]}],
   ['fast-3', qw(1 1 4), {OUT => [qw(1 2 3 4)]}],

   # Ensure an INCREMENT of Zero is rejected.
   ['inc-zero-1',	qw(1 0 10), {EXIT => 1}, {ERR => $err_inc_zero}],
   ['inc-zero-2',	qw(0 -0 0), {EXIT => 1}, {ERR => $err_inc_zero},
    {ERR_SUBST => 's/-0/0/'}],
   ['inc-zero-3',	qw(1 0.0 10), {EXIT => 1},{ERR => $err_inc_zero},
    {ERR_SUBST => 's/0.0/0/'}],
   ['inc-zero-4',	qw(1 -0.0e-10 10), {EXIT => 1},{ERR => $err_inc_zero},
    {ERR_SUBST => 's/-0\.0e-10/0/'}],

   # Ensure NaN arguments rejected.
   ['nan-first-1', qw(nan),       {EXIT => 1}, {ERR => $err_nan_arg}],
   ['nan-first-2', qw(NaN 2),     {EXIT => 1}, {ERR => $err_nan_arg},
    {ERR_SUBST => 's/NaN/nan/'}],
   ['nan-first-3', qw(nan 1 2),   {EXIT => 1}, {ERR => $err_nan_arg}],
   ['nan-first-4', qw(-- -nan),   {EXIT => 1}, {ERR => $err_nan_arg},
    {ERR_SUBST => 's/-nan/nan/'}],
   ['nan-inc-1',   qw(1 nan 2),   {EXIT => 1}, {ERR => $err_nan_arg}],
   ['nan-inc-2',   qw(1 -NaN 2),  {EXIT => 1}, {ERR => $err_nan_arg},
    {ERR_SUBST => 's/-NaN/nan/'}],
   ['nan-last-1',  qw(1 1 nan),   {EXIT => 1}, {ERR => $err_nan_arg}],
   ['nan-last-2',  qw(1 NaN),     {EXIT => 1}, {ERR => $err_nan_arg},
    {ERR_SUBST => 's/NaN/nan/'}],
   ['nan-last-3',  qw(0 -1 -NaN), {EXIT => 1}, {ERR => $err_nan_arg},
    {ERR_SUBST => 's/-NaN/nan/'}],
  );

# Append a newline to each entry in the OUT array.
my $t;
foreach $t (@Tests)
  {
    my $e;
    foreach $e (@$t)
      {
        $e->{OUT} = join ("\n", @{$e->{OUT}}) . "\n"
          if ref $e eq 'HASH' and exists $e->{OUT};
      }
  }

my $save_temps = $ENV{SAVE_TEMPS};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
