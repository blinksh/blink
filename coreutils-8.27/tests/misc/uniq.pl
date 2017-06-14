#!/usr/bin/perl
# Test uniq.

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

my $prog = 'uniq';
my $try = "Try '$prog --help' for more information.\n";

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

# When possible, create a "-z"-testing variant of each test.
sub add_z_variants($)
{
  my ($tests) = @_;
  my @new;
 TEST:
  foreach my $t (@$tests)
    {
      push @new, $t;

      # skip the obsolete-syntax tests
      $t->[0] =~ /^obs-plus/
        and next;

      my @args;
      my @list_of_hash;

      foreach my $e (@$t)
        {
          !ref $e
            and push (@args, $e), next;

          ref $e && ref $e eq 'HASH'
            or (warn "$0: $t->[0]: unexpected entry type\n"), next;
          my $tmp = $e;
          foreach my $k (qw(IN OUT))
            {
              my $val = $e->{$k};
              # skip any test whose input or output already contains a NUL byte
              if (defined $val)
                {
                  $val =~ /\0/
                    and next TEST;

                  # Convert each NL in input or output to \0.
                  $val =~ s/\n/\0/g;
                  $tmp = {$k => $val};
                  last;
                }
            }
          push @list_of_hash, $tmp;
        }

      shift @args; # discard test name

      # skip any test that uses the -z option
      grep /z/, @args
        and next;

      push @new, ["$t->[0]-z", '-z', @args, @list_of_hash];
    }
  return @new;
}

my @Tests =
(
 ['1', '', {IN=>''}, {OUT=>''}],
 ['2', '', {IN=>"a\na\n"}, {OUT=>"a\n"}],
 ['3', '', {IN=>"a\na"}, {OUT=>"a\n"}],
 ['4', '', {IN=>"a\nb"}, {OUT=>"a\nb\n"}],
 ['5', '', {IN=>"a\na\nb"}, {OUT=>"a\nb\n"}],
 ['6', '', {IN=>"b\na\na\n"}, {OUT=>"b\na\n"}],
 ['7', '', {IN=>"a\nb\nc\n"}, {OUT=>"a\nb\nc\n"}],

 # Ensure that newlines are not interpreted with -z.
 ['2z', '-z', {IN=>"a\na\n"}, {OUT=>"a\na\n\0"}],
 ['3z', '-z', {IN=>"a\na"}, {OUT=>"a\na\0"}],
 ['4z', '-z', {IN=>"a\nb"}, {OUT=>"a\nb\0"}],
 ['5z', '-z', {IN=>"a\na\nb"}, {OUT=>"a\na\nb\0"}],
 ['10z', '-z -f1', {IN=>"a\nb\n\0c\nb\n\0"}, {OUT=>"a\nb\n\0"}],
 ['20z', '-dz', {IN=>"a\na\n"}, {OUT=>""}],

 # Make sure that eight bit characters work
 ['8', '', {IN=>"ö\nv\n"}, {OUT=>"ö\nv\n"}],
 # Test output of -u option; only unique lines
 ['9', '-u', {IN=>"a\na\n"}, {OUT=>""}],
 ['10', '-u', {IN=>"a\nb\n"}, {OUT=>"a\nb\n"}],
 ['11', '-u', {IN=>"a\nb\na\n"}, {OUT=>"a\nb\na\n"}],
 ['12', '-u', {IN=>"a\na\n"}, {OUT=>""}],
 ['13', '-u', {IN=>"a\na\n"}, {OUT=>""}],
 #['5',  '-u',  "a\na\n",          "",                0],
 # Test output of -d option; only repeated lines
 ['20', '-d', {IN=>"a\na\n"}, {OUT=>"a\n"}],
 ['21', '-d', {IN=>"a\nb\n"}, {OUT=>""}],
 ['22', '-d', {IN=>"a\nb\na\n"}, {OUT=>""}],
 ['23', '-d', {IN=>"a\na\nb\n"}, {OUT=>"a\n"}],
 # Check the key options
 # If we skip over fields or characters, is the output deterministic?
 ['obs30', '-1', {IN=>"a a\nb a\n"}, {OUT=>"a a\n"}],
 ['31', qw(-f 1), {IN=>"a a\nb a\n"}, {OUT=>"a a\n"}],
 ['32', qw(-f 1), {IN=>"a a\nb b\n"}, {OUT=>"a a\nb b\n"}],
 ['33', qw(-f 1), {IN=>"a a a\nb a c\n"}, {OUT=>"a a a\nb a c\n"}],
 ['34', qw(-f 1), {IN=>"b a\na a\n"}, {OUT=>"b a\n"}],
 ['35', qw(-f 2), {IN=>"a a c\nb a c\n"}, {OUT=>"a a c\n"}],
 # Skip over characters.
 ['obs-plus40', '+1', {IN=>"aaa\naaa\n"}, {OUT=>"aaa\n"}],
 ['obs-plus41', '+1', {IN=>"baa\naaa\n"}, {OUT=>"baa\n"}],
 ['42', qw(-s 1), {IN=>"aaa\naaa\n"}, {OUT=>"aaa\n"}],
 ['43', qw(-s 2), {IN=>"baa\naaa\n"}, {OUT=>"baa\n"}],
 ['obs-plus44', qw(+1 --), {IN=>"aaa\naaa\n"}, {OUT=>"aaa\n"}],
 ['obs-plus45', qw(+1 --), {IN=>"baa\naaa\n"}, {OUT=>"baa\n"}],
 # Skip over fields and characters
 ['50', qw(-f 1 -s 1), {IN=>"a aaa\nb ab\n"}, {OUT=>"a aaa\nb ab\n"}],
 ['51', qw(-f 1 -s 1), {IN=>"a aaa\nb aaa\n"}, {OUT=>"a aaa\n"}],
 ['52', qw(-s 1 -f 1), {IN=>"a aaa\nb ab\n"}, {OUT=>"a aaa\nb ab\n"}],
 ['53', qw(-s 1 -f 1), {IN=>"a aaa\nb aaa\n"}, {OUT=>"a aaa\n"}],
 # Fixed in 2.0.15
 ['54', qw(-s 4), {IN=>"abc\nabcd\n"}, {OUT=>"abc\n"}],
 # Supported in 2.0.15
 ['55', qw(-s 0), {IN=>"abc\nabcd\n"}, {OUT=>"abc\nabcd\n"}],
 ['56', qw(-s 0), {IN=>"abc\n"}, {OUT=>"abc\n"}],
 ['57', qw(-w 0), {IN=>"abc\nabcd\n"}, {OUT=>"abc\n"}],
 # Only account for a number of characters
 ['60', qw(-w 1), {IN=>"a a\nb a\n"}, {OUT=>"a a\nb a\n"}],
 ['61', qw(-w 3), {IN=>"a a\nb a\n"}, {OUT=>"a a\nb a\n"}],
 ['62', qw(-w 1 -f 1), {IN=>"a a a\nb a c\n"}, {OUT=>"a a a\n"}],
 ['63', qw(-f 1 -w 1), {IN=>"a a a\nb a c\n"}, {OUT=>"a a a\n"}],
 # The blank after field one is checked too
 ['64', qw(-f 1 -w 4), {IN=>"a a a\nb a c\n"}, {OUT=>"a a a\nb a c\n"}],
 ['65', qw(-f 1 -w 3), {IN=>"a a a\nb a c\n"}, {OUT=>"a a a\n"}],
 # Make sure we don't break if the file contains \0
 ['90', '', {IN=>"a\0a\na\n"}, {OUT=>"a\0a\na\n"}],
 # Check fields separated by tabs and by spaces
 ['91', '', {IN=>"a\ta\na a\n"}, {OUT=>"a\ta\na a\n"}],
 ['92', qw(-f 1), {IN=>"a\ta\na a\n"}, {OUT=>"a\ta\na a\n"}],
 ['93', qw(-f 2), {IN=>"a\ta a\na a a\n"}, {OUT=>"a\ta a\n"}],
 ['94', qw(-f 1), {IN=>"a\ta\na\ta\n"}, {OUT=>"a\ta\n"}],
 # Check the count option; add tests for other options too
 ['101', '-c', {IN=>"a\nb\n"}, {OUT=>"      1 a\n      1 b\n"}],
 ['102', '-c', {IN=>"a\na\n"}, {OUT=>"      2 a\n"}],
 # Check the local -D (--all-repeated) option
 ['110', '-D', {IN=>"a\na\n"}, {OUT=>"a\na\n"}],
 ['111', qw(-D -w1), {IN=>"a a\na b\n"}, {OUT=>"a a\na b\n"}],
 ['112', qw(-D -c), {IN=>"a a\na b\n"}, {OUT=>""}, {EXIT=>1}, {ERR=>
  "$prog: printing all duplicated lines and repeat counts is meaningless\n$try"}
  ],
 ['113', '--all-repeated=separate', {IN=>"a\na\n"}, {OUT=>"a\na\n"}],
 ['114', '--all-repeated=separate',
  {IN=>"a\na\nb\nc\nc\n"}, {OUT=>"a\na\n\nc\nc\n"}],
 ['115', '--all-repeated=separate',
  {IN=>"a\na\nb\nb\nc\n"}, {OUT=>"a\na\n\nb\nb\n"}],
 ['116', '--all-repeated=prepend', {IN=>"a\na\n"}, {OUT=>"\na\na\n"}],
 ['117', '--all-repeated=prepend',
  {IN=>"a\na\nb\nc\nc\n"}, {OUT=>"\na\na\n\nc\nc\n"}],
 ['118', '--all-repeated=prepend', {IN=>"a\nb\n"}, {OUT=>""}],
 ['119', '--all-repeated=badoption', {IN=>"a\n"}, {OUT=>""}, {EXIT=>1},
  {ERR=>"$prog: invalid argument 'badoption' for '--all-repeated'\n"
        . "Valid arguments are:\n"
        . "  - 'none'\n"
        . "  - 'prepend'\n"
        . "  - 'separate'\n"
        . $try}],
 # Check that -d and -u suppress all output, as POSIX requires.
 ['120', qw(-d -u), {IN=>"a\na\n\b"}, {OUT=>""}],
 ['121', "-d -u -w$limits->{UINTMAX_OFLOW}", {IN=>"a\na\n\b"}, {OUT=>""}],
 ['122', "-d -u -w$limits->{SIZE_OFLOW}", {IN=>"a\na\n\b"}, {OUT=>""}],
 # Check that --zero-terminated is synonymous with -z.
 ['123', '--zero-terminated', {IN=>"a\na\nb"}, {OUT=>"a\na\nb\0"}],
 ['124', '--zero-terminated', {IN=>"a\0a\0b"}, {OUT=>"a\0b\0"}],
 # Check ignore-case
 ['125', '',              {IN=>"A\na\n"}, {OUT=>"A\na\n"}],
 ['126', '-i',            {IN=>"A\na\n"}, {OUT=>"A\n"}],
 ['127', '--ignore-case', {IN=>"A\na\n"}, {OUT=>"A\n"}],
 # Check grouping
 ['128', '--group=prepend', {IN=>"a\na\nb\n"}, {OUT=>"\na\na\n\nb\n"}],
 ['129', '--group=append',  {IN=>"a\na\nb\n"}, {OUT=>"a\na\n\nb\n\n"}],
 ['130', '--group=separate',{IN=>"a\na\nb\n"}, {OUT=>"a\na\n\nb\n"}],
 # no explicit grouping = separate
 ['131', '--group',         {IN=>"a\na\nb\n"}, {OUT=>"a\na\n\nb\n"}],
 ['132', '--group=both',    {IN=>"a\na\nb\n"}, {OUT=>"\na\na\n\nb\n\n"}],
 # Grouping in the special case of a single group
 ['133', '--group=prepend', {IN=>"a\na\n"}, {OUT=>"\na\na\n"}],
 ['134', '--group=append',  {IN=>"a\na\n"}, {OUT=>"a\na\n\n"}],
 ['135', '--group=separate',{IN=>"a\na\n"}, {OUT=>"a\na\n"}],
 ['136', '--group',         {IN=>"a\na\n"}, {OUT=>"a\na\n"}],
 # Grouping with empty input - should never print anything
 ['137', '--group=prepend',  {IN=>""}, {OUT=>""}],
 ['138', '--group=append',   {IN=>""}, {OUT=>""}],
 ['139', '--group=separate', {IN=>""}, {OUT=>""}],
 ['140', '--group=both',     {IN=>""}, {OUT=>""}],
 # Grouping with other options - must fail
 ['141', '--group -c',       {IN=>""}, {OUT=>""}, {EXIT=>1},
  {ERR=>"$prog: --group is mutually exclusive with -c/-d/-D/-u\n" .
        "Try 'uniq --help' for more information.\n"}],
 ['142', '--group -d',       {IN=>""}, {OUT=>""}, {EXIT=>1},
  {ERR=>"$prog: --group is mutually exclusive with -c/-d/-D/-u\n" .
        "Try 'uniq --help' for more information.\n"}],
 ['143', '--group -u',       {IN=>""}, {OUT=>""}, {EXIT=>1},
  {ERR=>"$prog: --group is mutually exclusive with -c/-d/-D/-u\n" .
        "Try 'uniq --help' for more information.\n"}],
 ['144', '--group -D',       {IN=>""}, {OUT=>""}, {EXIT=>1},
  {ERR=>"$prog: --group is mutually exclusive with -c/-d/-D/-u\n" .
        "Try 'uniq --help' for more information.\n"}],
 # Grouping with badoption
 ['145', '--group=badoption',{IN=>""}, {OUT=>""}, {EXIT=>1},
  {ERR=>"$prog: invalid argument 'badoption' for '--group'\n" .
        "Valid arguments are:\n" .
        "  - 'prepend'\n" .
        "  - 'append'\n" .
        "  - 'separate'\n" .
        "  - 'both'\n" .
        "Try '$prog --help' for more information.\n"}],
);

# Locale related tests

my $locale = $ENV{LOCALE_FR};
if ( defined $locale && $locale ne 'none' )
  {
    # I've only ever triggered the problem in a non-C locale.

    # See if isblank returns true for nbsp.
    my $x = qx!env printf '\xa0'| LC_ALL=$locale tr '[:blank:]' x!;
    # If so, expect just one line of output in the schar test.
    # Otherwise, expect two.
    my $in = " y z\n\xa0 y z\n";
    my $schar_exp = $x eq 'x' ? " y z\n" : $in;

    my @Locale_Tests =
    (
      # Test for a subtle, system-and-locale-dependent bug in uniq.
      ['schar', '-f1',  {IN => $in}, {OUT => $schar_exp},
        {ENV => "LC_ALL=$locale"}]
    );

    push @Tests, @Locale_Tests;
  }


# Set _POSIX2_VERSION=199209 in the environment of each obs-plus* test.
foreach my $t (@Tests)
  {
    $t->[0] =~ /^obs-plus/
      and push @$t, {ENV=>'_POSIX2_VERSION=199209'};
  }

@Tests = add_z_variants \@Tests;
@Tests = triple_test \@Tests;

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($prog, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
