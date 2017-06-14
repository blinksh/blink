#!/usr/bin/perl
# Test "mktemp".

# Copyright (C) 2007-2017 Free Software Foundation, Inc.

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

(my $ME = $0) =~ s|.*/||;

sub check_tmp($$)
{
  my ($file, $file_or_dir) = @_;

  my (undef, undef, $mode, undef) = stat $file
   or die "$ME: failed to stat $file: $!\n";
  my $required_mode;
  if ($file_or_dir eq 'D') {
    -d $file or die "$ME: $file isn't a directory\n";
    -x $file or die "$ME: $file isn't owner-searchable\n";
    $required_mode = 0700;
  } elsif ($file_or_dir eq 'F') {
    -f $file or die "$ME: $file isn't a regular file\n";
    $required_mode = 0600;
  }
  -r $file or die "$ME: $file isn't owner-readable\n";
  -w $file or die "$ME: $file isn't owner-writable\n";
  ($mode & 0777) == $required_mode
    or die "$ME: $file doesn't have required permissions\n";

  $file_or_dir eq 'D'
    and do { rmdir $file or die "$ME: failed to rmdir $file: $!\n" };
  $file_or_dir eq 'F'
    and do { unlink $file or die "$ME: failed to unlink $file: $!\n" };
}

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;
my $prog = 'mktemp';
my $bad_dir = 'no/such/dir';

my @Tests =
    (
     # test-name, [option, option, ...] {OUT=>"expected-output"}
     #
     ['too-many', '-q a b',
      {ERR=>"$prog: too many templates\n"
       . "Try '$prog --help' for more information.\n"}, {EXIT => 1} ],

     ['too-few-x', '-q foo.XX', {EXIT => 1},
      {ERR=>"$prog: too few X's in template 'foo.XX'\n"}],

     ['1f', 'bar.XXXX', {OUT => "bar.ZZZZ\n"},
      {OUT_SUBST => 's,\.....$,.ZZZZ,'},
      {POST => sub { my ($f) = @_; defined $f or return; chomp $f;
       check_tmp $f, 'F'; }}
     ],

     ['2f', '-- -XXXX', {OUT => "-ZZZZ\n"},
      {OUT_SUBST => 's,-....$,-ZZZZ,'},
      {POST => sub { my ($f) = @_; defined $f or return; chomp $f;
       check_tmp $f, 'F'; }}
     ],

     # Create a temporary directory.
     ['1d', '-d f.XXXX', {OUT => "f.ZZZZ\n"},
      {OUT_SUBST => 's,\.....$,.ZZZZ,'},
      {POST => sub { my ($f) = @_; defined $f or return; chomp $f;
       check_tmp $f, 'D'; }}
     ],

     # Use a template consisting solely of X's
     ['1d-allX', '-d XXXX', {OUT => "ZZZZ\n"},
      {PRE => sub {mkdir 'XXXX',0755 or die "XXXX: $!\n"}},
      {OUT_SUBST => 's,^....$,ZZZZ,'},
      {POST => sub { my ($f) = @_; defined $f or return; chomp $f;
       check_tmp $f, 'D'; rmdir 'XXXX' or die "rmdir XXXX: $!\n"; }}
     ],

     # Test -u
     ['uf', '-u f.XXXX', {OUT => "f.ZZZZ\n"},
      {OUT_SUBST => 's,\.....$,.ZZZZ,'},
      {POST => sub { my ($f) = @_; defined $f or return; chomp $f;
       -e $f and die "dry-run created file"; }}],
     ['ud', '-d --dry-run d.XXXX', {OUT => "d.ZZZZ\n"},
      {OUT_SUBST => 's,\.....$,.ZZZZ,'},
      {POST => sub { my ($f) = @_; defined $f or return; chomp $f;
       -e $f and die "dry-run created directory"; }}],

     # Test bad templates
     ['invalid-tl', '-t a/bXXXX',
      {ERR=>"$prog: invalid template, 'a/bXXXX', "
       . "contains directory separator\n"}, {EXIT => 1} ],

     ['invalid-t2', '--tmpdir=a /bXXXX',
      {ERR=>"$prog: invalid template, '/bXXXX'; "
       . "with --tmpdir, it may not be absolute\n"}, {EXIT => 1} ],

     # Suffix after X.
     ['suffix1f', 'aXXXXb', {OUT=>"aZZZZb\n"},
      {OUT_SUBST=>'s,a....b,aZZZZb,'},
      {POST => sub { my ($f) = @_; defined $f or return; chomp $f;
       check_tmp $f, 'F'; }}],
     ['suffix1d', '-d aXXXXb', {OUT=>"aZZZZb\n"},
      {OUT_SUBST=>'s,a....b,aZZZZb,'},
      {POST => sub { my ($f) = @_; defined $f or return; chomp $f;
       check_tmp $f, 'D'; }}],
     ['suffix1u', '-u aXXXXb', {OUT=>"aZZZZb\n"},
      {OUT_SUBST=>'s,a....b,aZZZZb,'},
      {POST => sub { my ($f) = @_; defined $f or return; chomp $f;
       -e $f and die "dry-run created file"; }}],

     ['suffix2f', 'aXXXXaaXXXXa', {OUT=>"aXXXXaaZZZZa\n"},
      {OUT_SUBST=>'s,a....a$,aZZZZa,'},
      {POST => sub { my ($f) = @_; defined $f or return; chomp $f;
       check_tmp $f, 'F'; }}],
     ['suffix2d', '-d --suffix= aXXXXaaXXXX', {OUT=>"aXXXXaaZZZZ\n"},
      {OUT_SUBST=>'s,a....$,aZZZZ,'},
      {POST => sub { my ($f) = @_; defined $f or return; chomp $f;
       check_tmp $f, 'D'; }}],

     ['suffix3f', '--suffix=b aXXXX', {OUT=>"aZZZZb\n"},
      {OUT_SUBST=>'s,a....b,aZZZZb,'},
      {POST => sub { my ($f) = @_; defined $f or return; chomp $f;
       check_tmp $f, 'F'; }}],

     ['suffix4f', '--suffix=X aXXXX', {OUT=>"aZZZZX\n"},
      {OUT_SUBST=>'s,^a....,aZZZZ,'},
      {POST => sub { my ($f) = @_; defined $f or return; chomp $f;
       check_tmp $f, 'F'; }}],

     ['suffix5f', '--suffix /b aXXXX', {EXIT=>1},
      {ERR=>"$prog: invalid suffix '/b', contains directory separator\n"}],

     ['suffix6f', 'aXXXX/b', {EXIT=>1},
      {ERR=>"$prog: invalid suffix '/b', contains directory separator\n"}],

     ['suffix7f', '--suffix= aXXXXb', {EXIT=>1},
      {ERR=>"$prog: with --suffix, template 'aXXXXb' must end in X\n"}],
     ['suffix7d', '-d --suffix=aXXXXb ""', {EXIT=>1},
      {ERR=>"$prog: with --suffix, template '' must end in X\n"}],

     ['suffix8f', 'aXXXX --suffix=b', {OUT=>"aZZZZb\n"},
      {OUT_SUBST=>'s,^a....,aZZZZ,'},
      {POST => sub { my ($f) = @_; defined $f or return; chomp $f;
       check_tmp $f, 'F'; }}],

     ['suffix9f', 'aXXXX --suffix=b', {EXIT=>1},
      {ENV=>"POSIXLY_CORRECT=1"},
      {ERR=>"$prog: too many templates\n"
       . "Try '$prog --help' for more information.\n"}],

     ['suffix10f', 'aXXb', {EXIT => 1},
      {ERR=>"$prog: too few X's in template 'aXXb'\n"}],
     ['suffix10d', '-d --suffix=X aXX', {EXIT => 1},
      {ERR=>"$prog: too few X's in template 'aXXX'\n"}],

     ['suffix11f', '--suffix=.txt', {OUT=>"./tmp.ZZZZZZZZZZ.txt\n"},
      {ENV=>"TMPDIR=."},
      {OUT_SUBST=>'s,\..{10}\.,.ZZZZZZZZZZ.,'},
      {POST => sub { my ($f) = @_; defined $f or return; chomp $f;
       check_tmp $f, 'F'; }}],


     # Test template with subdirectory
     ['tmp-w-slash', '--tmpdir=. a/bXXXX',
      {PRE => sub {mkdir 'a',0755 or die "a: $!\n"}},
      {OUT_SUBST => 's,b....$,bZZZZ,'},
      {OUT => "./a/bZZZZ\n"},
      {POST => sub { my ($f) = @_; defined $f or return; chomp $f;
       check_tmp $f, 'F'; unlink $f; rmdir 'a' or die "rmdir a: $!\n" }}
     ],

     ['pipe-bad-tmpdir',
      {ENV => "TMPDIR=$bad_dir"},
      {ERR_SUBST => "s,($bad_dir/)[^']+': .*,\$1...,"},
      {ERR => "$prog: failed to create file via template '$bad_dir/...\n"},
      {EXIT => 1}],
     ['pipe-bad-tmpdir-u', '-u', {OUT => "$bad_dir/tmp.ZZZZZZZZZZ\n"},
      {ENV => "TMPDIR=$bad_dir"},
      {OUT_SUBST => 's,\..{10}$,.ZZZZZZZZZZ,'}],
    );

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($ME, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
