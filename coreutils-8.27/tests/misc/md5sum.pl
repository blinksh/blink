#!/usr/bin/perl
# Basic tests for "md5sum".

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

my $prog = 'md5sum';

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my $degenerate = "d41d8cd98f00b204e9800998ecf8427e";

my $try_help = "Try 'md5sum --help' for more information.\n";

my @Tests =
    (
     ['1', {IN=> {f=> ''}},	{OUT=>"$degenerate  f\n"}],
     ['2', {IN=> {f=> 'a'}},	{OUT=>"0cc175b9c0f1b6a831c399e269772661  f\n"}],
     ['3', {IN=> {f=> 'abc'}},	{OUT=>"900150983cd24fb0d6963f7d28e17f72  f\n"}],
     ['4', {IN=> {f=> 'message digest'}},
                                {OUT=>"f96b697d7cb7938d525a2f31aaf161d0  f\n"}],
     ['5', {IN=> {f=> 'abcdefghijklmnopqrstuvwxyz'}},
                                {OUT=>"c3fcd3d76192e4007dfb496cca67e13b  f\n"}],
     ['6', {IN=> {f=> join ('', 'A'..'Z', 'a'..'z', '0'..'9')}},
                                {OUT=>"d174ab98d277d9f5a5611c2c9f419d9f  f\n"}],
     ['7', {IN=> {f=> '1234567890' x 8}},
                                {OUT=>"57edf4a22be3c955ac49da2e2107b67a  f\n"}],
     ['backslash-1', {IN=> {".\nfoo"=> ''}},
                                {OUT=>"\\$degenerate  .\\nfoo\n"}],
     ['backslash-2', {IN=> {".\\foo"=> ''}},
                                {OUT=>"\\$degenerate  .\\\\foo\n"}],
     ['check-1', '--check', {AUX=> {f=> ''}},
                                {IN=> {'f.md5' => "$degenerate  f\n"}},
                                {OUT=>"f: OK\n"}],

     # Same as above, but with an added empty line, to provoke --strict.
     ['ck-strict-1', '--check --strict', {AUX=> {f=> ''}},
                                {IN=> {'f.md5' => "$degenerate  f\n\n"}},
                                {OUT=>"f: OK\n"},
                                {ERR=>"md5sum: "
                                 . "WARNING: 1 line is improperly formatted\n"},
                                {EXIT=> 1}],

     # As above, but with the invalid line first, to ensure that following
     # lines are processed in spite of the preceding invalid input line.
     ['ck-strict-2', '--check --strict', {AUX=> {f=> ''}},
                                {IN=> {'in.md5' => "\n$degenerate  f\n"}},
                                {OUT=>"f: OK\n"},
                                {ERR=>"md5sum: "
                                 . "WARNING: 1 line is improperly formatted\n"},
                                {EXIT=> 1}],
     ['check-2', '--check', '--status', {IN=>{'f.md5' => "$degenerate  f\n"}},
                                {AUX=> {f=> 'foo'}}, {EXIT=> 1}],
     ['check-quiet1', '--check', '--quiet', {AUX=> {f=> ''}},
                                {IN=> {'f.md5' => "$degenerate  f\n"}},
                                {OUT=>""}],
     ['check-quiet2', '--check', '--quiet',
                                {IN=>{'f.md5' => "$degenerate  f\n"}},
                                {AUX=> {f=> 'foo'}}, {OUT=>"f: FAILED\n"},
                                {ERR=>"md5sum: WARNING: 1 computed"
                                       . " checksum did NOT match\n"},
                                {EXIT=> 1}],
     # Exercise new-after-8.6, easier-to-translate diagnostics.
     ['check-multifail', '--check',
                                {IN=>{'f.md5' =>
                                      "$degenerate  f\n"
                                      . "$degenerate  f\n"
                                      . "invalid\n" }},
                                {AUX=> {f=> 'foo'}},
                                {OUT=>"f: FAILED\nf: FAILED\n"},
                {ERR=>"md5sum: WARNING: 1 line is improperly formatted\n"
                    . "md5sum: WARNING: 2 computed checksums did NOT match\n"},
                                {EXIT=> 1}],
     # Similar to the above, but use --warn to evoke one more diagnostic.
     ['check-multifail-warn', '--check', '--warn',
                                {IN=>{'f.md5' =>
                                      "$degenerate  f\n"
                                      . "$degenerate  f\n"
                                      . "invalid\n" }},
                                {AUX=> {f=> 'foo'}},
                                {OUT=>"f: FAILED\nf: FAILED\n"},
              {ERR=>"md5sum: f.md5: 3: "
                              . "improperly formatted MD5 checksum line\n"
                  . "md5sum: WARNING: 1 line is improperly formatted\n"
                  . "md5sum: WARNING: 2 computed checksums did NOT match\n"},
                                {EXIT=> 1}],
     # The sha1sum and md5sum drivers share a lot of code.
     # Ensure that md5sum does *not* share the part that makes
     # sha1sum accept BSD format.
     ['check-bsd', '--check', {IN=> {'f.sha1' => "SHA1 (f) = $degenerate\n"}},
                                {AUX=> {f=> ''}},
                                {ERR=>"md5sum: f.sha1: no properly formatted "
                                       . "MD5 checksum lines found\n"},
                                {EXIT=> 1}],
     ['check-bsd2', '--check', {IN=> {'f.md5' => "MD5 (f) = $degenerate\n"}},
                                {AUX=> {f=> ''}}, {OUT=>"f: OK\n"}],
     ['check-bsd3', '--check', '--status',
                                {IN=> {'f.md5' => "MD5 (f) = $degenerate\n"}},
                                {AUX=> {f=> 'bar'}}, {EXIT=> 1}],
     ['check-openssl', '--check', {IN=> {'f.sha1' => "SHA1(f)= $degenerate\n"}},
                                {AUX=> {f=> ''}},
                                {ERR=>"md5sum: f.sha1: no properly formatted "
                                       . "MD5 checksum lines found\n"},
                                {EXIT=> 1}],
     ['check-openssl2', '--check', {IN=> {'f.md5' => "MD5(f)= $degenerate\n"}},
                                {AUX=> {f=> ''}}, {OUT=>"f: OK\n"}],
     ['check-openssl3', '--check', '--status',
                                {IN=> {'f.md5' => "MD5(f)= $degenerate\n"}},
                                {AUX=> {f=> 'bar'}}, {EXIT=> 1}],
     ['check-ignore-missing-1', '--check', '--ignore-missing',
                                {AUX=> {f=> ''}},
                                {IN=> {'f.md5' => "$degenerate  f\n".
                                                  "$degenerate  f.missing\n"}},
                                {OUT=>"f: OK\n"}],
     ['check-ignore-missing-2', '--check', '--ignore-missing',
                                {AUX=> {f=> ''}},
                                {IN=> {'f.md5' => "$degenerate  f\n".
                                                  "$degenerate  f.missing\n"}},
                                {OUT=>"f: OK\n"}],
     ['check-ignore-missing-3', '--check', '--quiet', '--ignore-missing',
                                {AUX=> {f=> ''}},
                                {IN=> {'f.md5' => "$degenerate  missing/f\n".
                                                  "$degenerate  f\n"}},
                                {OUT=>""}],
     ['check-ignore-missing-4', '--ignore-missing',
                                {IN=> {f=> ''}},
                                {ERR=>"md5sum: the --ignore-missing option is ".
                                   "meaningful only when verifying checksums\n".
                                   $try_help},
                                {EXIT=> 1}],
     ['check-ignore-missing-5', '--check', '--ignore-missing',
                                {AUX=> {f=> ''}},
                                {IN=> {'f.md5' => "$degenerate  missing\n"}},
                                {ERR=>
                                    "md5sum: f.md5: no file was verified\n"},
                                {EXIT=> 1}],
     # coreutils-8.25 with --ignore-missing treated checksums starting with 00
     # as if the file was not present
     ['check-ignore-missing-6', '--check', '--ignore-missing',
                                {AUX=> {f=> '9t'}},
                                {IN=> {'f.md5' =>
                                    "006999e6df389641adf1fa3a74801d9d  f\n"}},
                                {OUT=>"f: OK\n"}],
     ['bsd-segv', '--check', {IN=> {'z' => "MD5 ("}}, {EXIT=> 1},
      {ERR=> "$prog: z: no properly formatted MD5 checksum lines found\n"}],

     # Ensure that when there's a NUL byte among the checksum hex digits
     # we detect the invalid formatting and don't even open the file.
     # Up to coreutils-6.10, this would report:
     #   h: FAILED
     #   md5sum: WARNING: 1 of 1 computed checksum did NOT match
     ['nul-in-cksum', '--check', {IN=> {'h'=>("\0"x32)."  h\n"}}, {EXIT=> 1},
      {ERR=> "$prog: h: no properly formatted MD5 checksum lines found\n"}],
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
