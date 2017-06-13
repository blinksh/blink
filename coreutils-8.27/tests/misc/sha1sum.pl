#!/usr/bin/perl
# Test "sha1sum".

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

my $prog = 'sha1sum';

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my $sha_degenerate = "da39a3ee5e6b4b0d3255bfef95601890afd80709";

my @Tests =
    (
     ['s1', {IN=> {f=> ''}},
                        {OUT=>"$sha_degenerate  f\n"}],
     ['s2', {IN=> {f=> 'a'}},
                        {OUT=>"86f7e437faa5a7fce15d1ddcb9eaeaea377667b8  f\n"}],
     ['s3', {IN=> {f=> 'abc'}},
                        {OUT=>"a9993e364706816aba3e25717850c26c9cd0d89d  f\n"}],
     ['s4',
      {IN=> {f=> 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'}},
                        {OUT=>"84983e441c3bd26ebaae4aa1f95129e5e54670f1  f\n"}],
     ['s5', {IN=> {f=> 'abcdefghijklmnopqrstuvwxyz'}},
                        {OUT=>"32d10c7b8cf96570ca04ce37f2a19d84240d3a89  f\n"}],
     ['s6', {IN=> {f=> join ('', 'A'..'Z', 'a'..'z', '0'..'9')}},
                        {OUT=>"761c457bf73b14d27e9e9265c46f4b4dda11f940  f\n"}],
     ['s7', {IN=> {f=> '1234567890' x 8}},
                        {OUT=>"50abf5706a150990a08b2c5ea40fa0e585554732  f\n"}],
     ['million-a', {IN=> {f=> 'a' x 1000000}},
                        {OUT=>"34aa973cd4c4daa4f61eeb2bdbad27316534016f  f\n"}],
     ['bs-sha-1', {IN=> {".\nfoo"=> ''}},
                        {OUT=>"\\$sha_degenerate  .\\nfoo\n"}],
     ['bs-sha-2', {IN=> {".\\foo"=> ''}},
                        {OUT=>"\\$sha_degenerate  .\\\\foo\n"}],
     # The sha1sum and md5sum drivers share a lot of code.
     # Ensure that sha1sum does *not* share the part that makes
     # md5sum accept BSD format.
     ['check-bsd', '--check', {IN=> {'f.md5' => "MD5 (f) = $sha_degenerate\n"}},
                        {AUX=> {f=> ''}},
                        {ERR=>"sha1sum: f.md5: no properly formatted "
                          . "SHA1 checksum lines found\n"},
                        {EXIT=> 1}],
     ['check-bsd2', '--check',
                        {IN=> {'f.sha1' => "SHA1 (f) = $sha_degenerate\n"}},
                        {AUX=> {f=> ''}}, {OUT=>"f: OK\n"}],
     ['check-bsd3', '--check', '--status',
                        {IN=> {'f.sha1' => "SHA1 (f) = $sha_degenerate\n"}},
                        {AUX=> {f=> 'bar'}}, {EXIT=> 1}],
     ['check-openssl', '--check',
                        {IN=> {'f.md5' => "MD5(f)= $sha_degenerate\n"}},
                        {AUX=> {f=> ''}},
                        {ERR=>"sha1sum: f.md5: no properly formatted "
                          . "SHA1 checksum lines found\n"},
                        {EXIT=> 1}],
     ['check-openssl2', '--check',
                        {IN=> {'f.sha1' => "SHA1(f)= $sha_degenerate\n"}},
                        {AUX=> {f=> ''}}, {OUT=>"f: OK\n"}],
     ['check-openssl3', '--check', '--status',
                        {IN=> {'f.sha1' => "SHA1(f)= $sha_degenerate\n"}},
                        {AUX=> {f=> 'bar'}}, {EXIT=> 1}],
     ['bsd-segv', '--check', {IN=> {'z' => "SHA1 ("}}, {EXIT=> 1},
      {ERR=> "$prog: z: no properly formatted SHA1 checksum lines found\n"}],
    );

# Insert the '--text' argument for each test.
my $t;
foreach $t (@Tests)
  {
    splice @$t, 1, 0, '--text' unless @$t[1] =~ /--check/;
  }

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($prog, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
