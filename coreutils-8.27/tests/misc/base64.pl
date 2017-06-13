#!/usr/bin/perl
# Exercise base{32,64}.

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

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

# Return the encoding of a string of N 'a's.
sub enc64($)
{
  my ($n) = @_;
  my %remainder = ( 0 => '', 1 => 'YQ==', 2 => 'YWE=' );
  return 'YWFh' x ($n / 3) . $remainder{$n % 3};
}

sub enc32($)
{
  my ($n) = @_;
  my %remainder = ( 0 => '', 1 => 'ME======', 2 => 'MFQQ====',
                    3 => 'MFQWC===', 4 => 'MFQWCYI=');
  return 'MFQWCYLB' x ($n / 5) . $remainder{$n % 5};
}

# Function reference to appropriate encoder
my $enc;

# An encoded string of length 4KB, using 3K "a"s.
my $a3k;
my @a3k_nl;

# Return a copy of S, with newlines inserted every WIDTH bytes.
# Ensure that the result (if not the empty string) is newline-terminated.
sub wrap($$)
{
  my ($s, $width) = @_;
  $s =~ s/(.{$width})/$1\n/g;
  substr ($s, -1, 1) ne "\n"
    and $s .= "\n";
  return $s;
}

my @Tests;

sub gen_tests($)
{
  my ($prog) = @_;
  @Tests=
    (
     ['empty', {IN=>''}, {OUT=>""}],
     ['inout1', {IN=>'a'x1}, {OUT=>&$enc(1)."\n"}],
     ['inout2', {IN=>'a'x2}, {OUT=>&$enc(2)."\n"}],
     ['inout3', {IN=>'a'x3}, {OUT=>&$enc(3)."\n"}],
     ['inout4', {IN=>'a'x4}, {OUT=>&$enc(4)."\n"}],
     ['inout5', {IN=>'a'x5}, {OUT=>&$enc(5)."\n"}],
     ['wrap', '--wrap 0', {IN=>'a'}, {OUT=>&$enc(1)}],
     ['wrap-zero', '--wrap 08', {IN=>'a'}, {OUT=>&$enc(1)."\n"}],
     ['wrap5-39', '--wrap=5', {IN=>'a' x 39}, {OUT=>wrap &$enc(39),5}],
     ['wrap5-40', '--wrap=5', {IN=>'a' x 40}, {OUT=>wrap &$enc(40),5}],
     ['wrap5-41', '--wrap=5', {IN=>'a' x 41}, {OUT=>wrap &$enc(41),5}],
     ['wrap5-42', '--wrap=5', {IN=>'a' x 42}, {OUT=>wrap &$enc(42),5}],
     ['wrap5-43', '--wrap=5', {IN=>'a' x 43}, {OUT=>wrap &$enc(43),5}],
     ['wrap5-44', '--wrap=5', {IN=>'a' x 44}, {OUT=>wrap &$enc(44),5}],
     ['wrap5-45', '--wrap=5', {IN=>'a' x 45}, {OUT=>wrap &$enc(45),5}],
     ['wrap5-46', '--wrap=5', {IN=>'a' x 46}, {OUT=>wrap &$enc(46),5}],

     ['wrap-bad-1', '-w0x0', {IN=>''}, {OUT=>""},
      {ERR_SUBST => 's/base..:/base..:/'},
      {ERR => "base..: invalid wrap size: '0x0'\n"}, {EXIT => 1}],
     ['wrap-bad-2', '-w1k', {IN=>''}, {OUT=>""},
      {ERR_SUBST => 's/base..:/base..:/'},
      {ERR => "base..: invalid wrap size: '1k'\n"}, {EXIT => 1}],
     ['wrap-bad-3', '-w-1', {IN=>''}, {OUT=>""},
      {ERR_SUBST => 's/base..:/base..:/'},
      {ERR => "base..: invalid wrap size: '-1'\n"}, {EXIT => 1}],
     ['wrap-bad-4', '-w-0', {IN=>''}, {OUT=>""},
      {ERR_SUBST => 's/base..:/base..:/'},
      {ERR => "base..: invalid wrap size: '-0'\n"}, {EXIT => 1}],

     ['buf-1',   '--decode', {IN=>&$enc(1)}, {OUT=>'a' x 1}],
     ['buf-2',   '--decode', {IN=>&$enc(2)}, {OUT=>'a' x 2}],
     ['buf-3',   '--decode', {IN=>&$enc(3)}, {OUT=>'a' x 3}],
     ['buf-4',   '--decode', {IN=>&$enc(4)}, {OUT=>'a' x 4}],
     # 4KB worth of input.
     ['buf-4k0', '--decode', {IN=>&$enc(3072+0)}, {OUT=>'a' x (3072+0)}],
     ['buf-4k1', '--decode', {IN=>&$enc(3072+1)}, {OUT=>'a' x (3072+1)}],
     ['buf-4k2', '--decode', {IN=>&$enc(3072+2)}, {OUT=>'a' x (3072+2)}],
     ['buf-4k3', '--decode', {IN=>&$enc(3072+3)}, {OUT=>'a' x (3072+3)}],
     ['buf-4km1','--decode', {IN=>&$enc(3072-1)}, {OUT=>'a' x (3072-1)}],
     ['buf-4km2','--decode', {IN=>&$enc(3072-2)}, {OUT=>'a' x (3072-2)}],
     ['buf-4km3','--decode', {IN=>&$enc(3072-3)}, {OUT=>'a' x (3072-3)}],
     ['buf-4km4','--decode', {IN=>&$enc(3072-4)}, {OUT=>'a' x (3072-4)}],

     # Exercise the case in which the final base-64 byte is
     # in a buffer all by itself.
     ['b4k-1',   '--decode', {IN=>$a3k_nl[1]}, {OUT=>'a' x (3072+0)}],
     ['b4k-2',   '--decode', {IN=>$a3k_nl[2]}, {OUT=>'a' x (3072+0)}],
     ['b4k-3',   '--decode', {IN=>$a3k_nl[3]}, {OUT=>'a' x (3072+0)}],
    );

  if ($prog eq "base64")
    {
        push @Tests, (
          ['baddecode', '--decode', {IN=>'a'}, {OUT=>""},
          {ERR_SUBST => 's/.*: invalid input//'}, {ERR => "\n"}, {EXIT => 1}],
          ['baddecode2', '--decode', {IN=>'ab'}, {OUT=>"i"},
          {ERR_SUBST => 's/.*: invalid input//'}, {ERR => "\n"}, {EXIT => 1}],
          ['baddecode3', '--decode', {IN=>'Zzz'}, {OUT=>"g<"},
          {ERR_SUBST => 's/.*: invalid input//'}, {ERR => "\n"}, {EXIT => 1}],
          ['baddecode4', '--decode', {IN=>'Zz='}, {OUT=>"g"},
          {ERR_SUBST => 's/.*: invalid input//'}, {ERR => "\n"}, {EXIT => 1}],
          ['baddecode5', '--decode', {IN=>'Z==='}, {OUT=>""},
          {ERR_SUBST => 's/.*: invalid input//'}, {ERR => "\n"}, {EXIT => 1}]
        );
    }

  # For each non-failing test, create a --decode test using the
  # expected output as input.  Also, add tests inserting newlines.
  my @new;
  foreach my $t (@Tests)
  {
      my $exit_val;
      my $in;
      my @out;

      # If the test has a single option of "--decode", then skip it.
      !ref $t->[1] && $t->[1] eq '--decode'
      and next;

      foreach my $e (@$t)
      {
          ref $e && ref $e eq 'HASH'
          or next;
          defined $e->{EXIT}
          and $exit_val = $e->{EXIT};
          defined $e->{IN}
          and $in = $e->{IN};
          if (defined $e->{OUT})
          {
              my $t = $e->{OUT};
              push @out, $t;
              my $len = length $t;
              foreach my $i (0..$len)
              {
                  my $u = $t;
                  substr ($u, $i, 0) = "\n";
                  push @out, $u;
                  10 <= $i
                  and last;
              }
          }
      }
      $exit_val
      and next;

      my $i = 0;
      foreach my $o (@out)
      {
          push @new, ["d$i-$t->[0]", '--decode', {IN => $o}, {OUT => $in}];
          ++$i;
      }
  }
  push @Tests, @new;
}

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = 0;
foreach my $prog (qw(base32 base64))
  {
    $enc = $prog eq "base32" ? \&enc32 : \&enc64;

    # Construct an encoded string of length 4KB, using 3K "a"s.
    $a3k = &$enc(3072);
    @a3k_nl = ();
    # A few copies, each with different number of newlines at the start.
    for my $k (0..3)
      {
        (my $t = $a3k) =~ s/^/"\n"x $k/e;
        push @a3k_nl, $t;
      }

    gen_tests($prog);

    $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
    if ($fail != 0)
      {
        last;
      }
  }

exit $fail;
