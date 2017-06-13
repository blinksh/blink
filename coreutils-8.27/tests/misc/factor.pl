#!/usr/bin/perl
# Basic tests for "factor".

# Copyright (C) 1998-2017 Free Software Foundation, Inc.

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
my $prog = 'factor';

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my @Tests =
    (
     ['1', '9',          {OUT => '3 3'}],
     ['1a', '7',         {OUT => '7'}],
     ['1b', '  +7',      {OUT => '7'}],
     ['2', '4294967291', {OUT => '4294967291'}],
     ['3', '4294967292', {OUT => '2 2 3 3 7 11 31 151 331'}],
     ['4', '4294967293', {OUT => '9241 464773'}],

     ['a', '4294966201', {OUT => '12197 352133'}],
     ['b', '4294966339', {OUT => '13187 325697'}],
     ['c', '4294966631', {OUT => '13729 312839'}],
     ['d', '4294966457', {OUT => '14891 288427'}],
     ['e', '4294966759', {OUT => '21649 198391'}],
     ['f', '4294966573', {OUT => '23071 186163'}],
     ['g', '4294967101', {OUT => '23603 181967'}],
     ['h', '4294966519', {OUT => '34583 124193'}],
     ['i', '4294966561', {OUT => '36067 119083'}],
     ['j', '4294966901', {OUT => '37747 113783'}],
     ['k', '4294966691', {OUT => '39241 109451'}],
     ['l', '4294966969', {OUT => '44201 97169'}],
     ['m', '4294967099', {OUT => '44483 96553'}],
     ['n', '4294966271', {OUT => '44617 96263'}],
     ['o', '4294966789', {OUT => '50411 85199'}],
     ['p', '4294966189', {OUT => '53197 80737'}],
     ['q', '4294967213', {OUT => '57139 75167'}],
     ['s', '4294967071', {OUT => '65521 65551'}],
     ['t', '4294966194', {OUT => '2 3 3 3 3 3 3 3 53 97 191'}],
     ['u', '4294966272', {OUT => '2 2 2 2 2 2 2 2 2 2 3 23 89 683'}],
     ['v', '4294966400', {OUT => '2 2 2 2 2 2 2 5 5 1342177'}],
     ['w', '4294966464', {OUT => '2 2 2 2 2 2 3 3 3 2485513'}],
     ['x', '4294966896', {OUT => '2 2 2 2 3 3 3 11 607 1489'}],
     ['y', '4294966998', {OUT => '2 3 7 3917 26107'}],
     ['z', '-1',
      # Map newer glibc diagnostic to expected.
      # Also map OpenBSD 5.1's "unknown option" to expected "invalid option".
      {ERR_SUBST => q!s/'1'/1/;s/unknown/invalid/!},
      {ERR => "$prog: invalid option -- 1\n"
       . "Try '$prog --help' for more information.\n"},
      {EXIT => 1}],
     ['cont', 'a 4',
      {OUT => "4: 2 2\n"},
      {ERR => "$prog: 'a' is not a valid positive integer\n"},
      {EXIT => 1}],
     ['bug-2012-a', '465658903', {OUT => '15259 30517'}],
     ['bug-2012-b', '2242724851', {OUT => '33487 66973'}],
     ['bug-2012-c', '6635692801', {OUT => '57601 115201'}],
     ['bug-2012-d', '17709149503', {OUT => '94099 188197'}],
     ['bug-2012-e', '17754345703', {OUT => '94219 188437'}],
     # Infinite loop bugs in v8.20 to 8.26 inclusive
     ['bug-2016-a', '158909489063877810457',
      {OUT => '3401347 3861211 12099721'}],
     ['bug-2016-b', '222087527029934481871',
      {OUT => '15601 26449 111427 4830277'}],
     ['bug-2016-c', '12847291069740315094892340035',
      {OUT => '5 4073 18899 522591721 63874247821'}],
    );

# If we have GMP support, append tests to exercise it.
(system "grep '^#define HAVE_GMP 1' $ENV{CONFIG_HEADER} > /dev/null") == 0
  and push (@Tests,
            ['bug-gmp-2_sup_128', '340282366920938463463374607431768211456',
             {OUT => '2 'x127 . '2'}],
            ['bug-gmp-2_sup_256',
             '115792089237316195423570985008687907853'
             . '269984665640564039457584007913129639936',
             {OUT => '2 'x255 . '2'}]);

# Prepend the command line argument and append a newline to end
# of each expected 'OUT' string.
my $t;

Test:
foreach $t (@Tests)
  {
    (my $arg1 = $t->[1]) =~ s| *\+?||;

    # Don't fiddle with expected OUT string if there's a nonzero exit status.
    foreach my $e (@$t)
      {
        ref $e eq 'HASH' && exists $e->{EXIT} && $e->{EXIT}
          and next Test;
      }

    foreach my $e (@$t)
      {
        ref $e eq 'HASH' && exists $e->{OUT}
          and $e->{OUT} = "$arg1: $e->{OUT}\n"
      }
  }

my $save_temps = $ENV{SAVE_TEMPS};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
