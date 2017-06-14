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

my $limits = getlimits ();

my $prog = 'test';

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

sub digest_test ($)
{
  my ($t) = @_;
  my @args;
  my $ret = 0;
  my @list_of_hashref;
  foreach my $e (@$t)
    {
      !ref $e
        and push (@args, $e), next;
      ref $e eq 'HASH'
        or (warn "$0: $t->[0]: unexpected entry type\n"), next;

      exists $e->{EXIT}
        and $ret = $e->{EXIT}, next;

      push @list_of_hashref, $e;
    }
  shift @args; # discard test name
  my $flags = join ' ', @args;

  return ($flags, $ret, \@list_of_hashref);
}

sub add_inverse_op_tests($)
{
  my ($tests) = @_;
  my @new;

  my %inverse_op =
    (
     eq => 'ne',
     lt => 'ge',
     gt => 'le',
    );

  foreach my $t (@$tests)
    {
      push @new, $t;

      my $test_name = $t->[0];
      my ($flags, $ret, $LoH) = digest_test $t;

      # Generate corresponding tests of inverse ops.
      # E.g. generate tests of '-ge' from those of '-lt'.
      foreach my $op (qw(gt lt eq))
        {
          if ($test_name =~ /$op-/ && $flags =~ / -$op /)
            {
              my $inv = $inverse_op{$op};
              $test_name =~ s/$op/$inv/;
              $flags =~ s/-$op/-$inv/;
              $ret = 1 - $ret;
              push (@new, [$test_name, $flags, {EXIT=>$ret}, @$LoH]);
            }
        }
    }
  return @new;
}

sub add_pn_tests($)
{
  my ($tests) = @_;
  my @new;

  # Generate parenthesized and negated versions of each test.
  # There are a few exceptions.
  my %not_N   = map {$_ => 1} qw (1a);
  my %not_P   = map {$_ => 1} qw (1a
                                  streq-6 strne-6
                                  paren-1 paren-2 paren-3 paren-4 paren-5);
  foreach my $t (@$tests)
    {
      push @new, $t;

      my $test_name = $t->[0];
      my ($flags, $ret, $LoH) = digest_test $t;
      next if $ret == 2;

      push (@new, ["N-$test_name", "! $flags", {EXIT=>1-$ret}, @$LoH])
        unless $not_N{$test_name};
      push (@new, ["P-$test_name", "'(' $flags ')'", {EXIT=>$ret}, @$LoH])
        unless $not_P{$test_name};
      push (@new, ["NP-$test_name", "! '(' $flags ')'", {EXIT=>1-$ret}, @$LoH])
        unless $not_P{$test_name};
      push (@new, ["NNP-$test_name", "! ! '(' $flags ')'", {EXIT=>$ret, @$LoH}])
        unless $not_P{$test_name};
    }

  return @new;
}

my @Tests =
(
  ['1a', {EXIT=>1}],
  ['1b', qw(-z '')],
  ['1c', 'any-string'],
  ['1d', qw(-n any-string)],
  ['1e', "''", {EXIT=>1}],
  ['1f', '-'],
  ['1g', '--'],
  ['1h', '-0'],
  ['1i', '-f'],
  ['1j', '--help'],
  ['1k', '--version'],

  ['streq-1', qw(t = t)],
  ['streq-2', qw(t = f), {EXIT=>1}],
  ['streqeq-1', qw(t == t)],
  ['streqeq-2', qw(t == f), {EXIT=>1}],
  ['streq-3', qw(! = !)],
  ['streq-4', qw(= = =)],
  ['streq-5', "'(' = '('"],
  ['streq-6', "'(' = ')'", {EXIT=>1}],
  ['strne-1', qw(t != t), {EXIT=>1}],
  ['strne-2', qw(t != f)],
  ['strne-3', qw(! != !), {EXIT=>1}],
  ['strne-4', qw(= != =), {EXIT=>1}],
  ['strne-5', "'(' != '('", {EXIT=>1}],
  ['strne-6', "'(' != ')'"],

  ['and-1', qw(t -a t)],
  ['and-2', qw('' -a t), {EXIT=>1}],
  ['and-3', qw(t -a ''), {EXIT=>1}],
  ['and-4', qw('' -a ''), {EXIT=>1}],

  ['or-1', qw(t -o t)],
  ['or-2', qw('' -o t)],
  ['or-3', qw(t -o '')],
  ['or-4', qw('' -o ''), {EXIT=>1}],

  ['eq-1', qw(9 -eq 9)],
  ['eq-2', qw(0 -eq 0)],
  ['eq-3', qw(0 -eq 00)],
  ['eq-4', qw(8 -eq 9), {EXIT=>1}],
  ['eq-5', qw(1 -eq 0), {EXIT=>1}],
  ['eq-6', "$limits->{UINTMAX_OFLOW} -eq 0", {EXIT=>1}],

  ['gt-1', qw(5 -gt 5), {EXIT=>1}],
  ['gt-2', qw(5 -gt 4)],
  ['gt-3', qw(4 -gt 5), {EXIT=>1}],
  ['gt-4', qw(-1 -gt -2)],
  ['gt-5', "$limits->{UINTMAX_OFLOW} -gt $limits->{INTMAX_UFLOW}"],

  ['lt-1', qw(5 -lt 5), {EXIT=>1}],
  ['lt-2', qw(5 -lt 4), {EXIT=>1}],
  ['lt-3', qw(4 -lt 5)],
  ['lt-4', qw(-1 -lt -2), {EXIT=>1}],
  ['lt-5', "$limits->{INTMAX_UFLOW} -lt $limits->{UINTMAX_OFLOW}"],

  ['inv-1', qw(0x0 -eq 00), {EXIT=>2},
   {ERR=>"$prog: invalid integer '0x0'\n"}],

  ['t1', "-t"],
  ['t2', qw(-t 1), {EXIT=>1}],

  ['paren-1', "'(' '' ')'", {EXIT=>1}],
  ['paren-2', "'(' '(' ')'"],
  ['paren-3', "'(' ')' ')'"],
  ['paren-4', "'(' ! ')'"],
  ['paren-5', "'(' -a ')'"],
);

@Tests = add_inverse_op_tests \@Tests;
@Tests = add_pn_tests \@Tests;

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($prog, \$prog, \@Tests, $save_temps, $verbose);
exit $fail;
