#!/usr/bin/perl

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

(my $ME = $0) =~ s|.*/||;
my $prog = 'ls';

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my $saved_ls_colors;

sub push_ls_colors($)
{
  $saved_ls_colors = $ENV{LS_COLORS} || '';
  $ENV{LS_COLORS} = $_[0];
}

sub restore_ls_colors()
{
  $ENV{LS_COLORS} = $saved_ls_colors;
}

# If the string $S is a well-behaved file name, simply return it.
# If it contains white space, quotes, etc., quote it, and return the new string.
sub shell_quote($)
{
  my ($s) = @_;
  if ($s =~ m![^\w+/.,-]!)
    {
      # Convert each single quote to '\''
      $s =~ s/\'/\'\\\'\'/g;
      # Then single quote the string.
      $s = "'$s'";
    }
  return $s;
}

# Set up files used by the setuid-etc tests; skip this entire test if
# that cannot be done.
sub setuid_setup()
{
  my $test = 'env test';
  system (qq(touch setuid && chmod u+s setuid && $test -u setuid &&
           touch setgid && chmod g+s setgid && $test -g setgid &&
           mkdir sticky && chmod +t sticky  && $test -k sticky &&
           mkdir owt    && chmod +t,o+w owt && $test -k owt &&
           mkdir owr    && chmod o+w owr)) == 0
             or CuSkip::skip "$ME: cannot create setuid/setgid/sticky files,"
                 . "so can't run this test\n";
}

sub mk_file(@)
{
  foreach my $f (@_)
    {
      open (F, '>', $f) && close F
        or die "creating $f: $!\n";
    }
}

sub mkdir_d {mkdir 'd',0755 or die "d: $!\n"}
sub rmdir_d {rmdir 'd'      or die "d: $!\n"}
my $mkdir = {PRE => sub {mkdir_d}};
my $rmdir = {POST => sub {rmdir_d}};
my $mkdir_reg = {PRE => sub {mkdir_d; mk_file 'd/f' }};
my $rmdir_reg = {POST => sub {unlink 'd/f' or die "d/f: $!\n";
                              rmdir 'd' or die "d: $!\n"}};

my $mkdir2 = {PRE => sub {mkdir 'd',0755 or die "d: $!\n";
                          mkdir 'd/e',0755 or die "d/e: $!\n" }};
my $rmdir2 = {POST => sub {rmdir 'd/e' or die "d/e: $!\n";
                           rmdir 'd' or die "d: $!\n" }};

my $target = {PRE => sub {
                mkdir 'd',0755 or die "d: $!\n";
                symlink '.', 'd/X' or die "d/X: $!\n";
                push_ls_colors('ln=target')
              }};
my $target2 = {POST => sub {unlink 'd/X' or die "d/X: $!\n";
                            rmdir 'd' or die "d: $!\n";
                            restore_ls_colors
                            }};
my $slink_d = {PRE => sub {symlink '/', 'd' or die "d: $!\n";
                           push_ls_colors('ln=01;36:di=01;34:or=40;31;01')
                           }};
my $unlink_d = {POST => sub {unlink 'd' or die "d: $!\n"; restore_ls_colors}};

my $mkdir_d_slink = {PRE => sub {mkdir 'd',0755 or die "d: $!\n";
                                 symlink '/', 'd/s' or die "d/s: $!\n" }};
my $rmdir_d_slink = {POST => sub {unlink 'd/s' or die "d/s: $!\n";
                                  rmdir 'd' or die "d: $!\n" }};

sub make_j_d ()
{
  mkdir 'j', 0700 or die "creating j: $!\n";
  mk_file 'j/d';
  chmod 0555, 'j/d' or die "making j/d executable: $!\n";
}

my @v1 = (qw(0 9 A Z a z), 'zz~', 'zz', 'zz.~1~', 'zz.0');
my @v_files = ((map { ".$_" } @v1), @v1);
my $exe_in_subdir = {PRE => sub { make_j_d (); push_ls_colors('ex=01;32') }};
my $remove_j = {POST => sub {unlink 'j/d' or die "j/d: $!\n";
                             rmdir 'j' or die "j: $!\n";
                             restore_ls_colors }};

my $e = "\e[0m";
my $q_bell = {IN => {"q\a" => ''}};
my @Tests =
    (
     # test-name options input expected-output
     #
     # quoting tests............................................
     ['q-',        $q_bell, {OUT => "q\a\n"}, {EXIT => 0}],
     ['q-N', '-N', $q_bell, {OUT => "q\a\n"}, {ERR => ''}],
     ['q-q', '-q', $q_bell, {OUT => "q?\n"}],
     ['q-Q', '-Q', $q_bell, {OUT => "\"q\\a\"\n"}],

     ['q-qs-lit',    '--quoting=literal',     $q_bell, {OUT => "q\a\n"}],
     ['q-qs-sh',     '--quoting=shell',       $q_bell, {OUT => "q\a\n"}],
     ['q-qs-sh-a',   '--quoting=shell-always',$q_bell, {OUT => "'q\a'\n"}],
     ['q-qs-sh-e',   '--quoting=shell-escape',$q_bell, {OUT => "'q'\$'\\a'\n"}],
     ['q-qs-c',      '--quoting=c',           $q_bell, {OUT => "\"q\\a\"\n"}],
     ['q-qs-esc',    '--quoting=escape',      $q_bell, {OUT => "q\\a\n"}],
     ['q-qs-loc',    '--quoting=locale',      $q_bell, {OUT => "'q\\a'\n"}],
     ['q-qs-cloc',   '--quoting=clocale',     $q_bell, {OUT => "\"q\\a\"\n"}],

     ['q-qs-lit-q',  '--quoting=literal -q',  $q_bell, {OUT => "q?\n"}],
     ['q-qs-sh-q',   '--quoting=shell -q',    $q_bell, {OUT => "q?\n"}],
     ['q-qs-sh-a-q', '--quoting=shell-al -q', $q_bell, {OUT => "'q?'\n"}],
     ['q-qs-sh-e-q', '--quoting=shell-escape -q',
                                              $q_bell, {OUT => "'q'\$'\\a'\n"}],
     ['q-qs-c-q',    '--quoting=c -q',        $q_bell, {OUT => "\"q\\a\"\n"}],
     ['q-qs-esc-q',  '--quoting=escape -q',   $q_bell, {OUT => "q\\a\n"}],
     ['q-qs-loc-q',  '--quoting=locale -q',   $q_bell, {OUT => "'q\\a'\n"}],
     ['q-qs-cloc-q', '--quoting=clocale -q',  $q_bell, {OUT => "\"q\\a\"\n"}],

     ['q-qs-c-1', '--quoting=c',
      {IN => {"t\004" => ''}}, {OUT => "\"t\\004\"\n"}],

     ['emptydir', 'd',  {OUT => ''}, $mkdir, $rmdir],
     ['emptydir-x2', 'd d',  {OUT => "d:\n\nd:\n"}, $mkdir, $rmdir],
     ['emptydir-R', '-R d',  {OUT => "d:\n"}, $mkdir, $rmdir],

     # test 'ls -R .' ............................................
     ['R-dot', '--ignore="[a-ce-zA-Z]*" -R .',  {OUT => ".:\nd\n\n\./d:\n"},
      $mkdir, $rmdir],

     ['slink-dir-F',     '-F d', {OUT => "d@\n"}, $slink_d, $unlink_d],
     ['slink-dir-dF',   '-dF d', {OUT => "d@\n"}, $slink_d, $unlink_d],
     ['slinkdir-dFH',  '-dFH d', {OUT => "d/\n"}, $slink_d, $unlink_d],
     ['slinkdir-dFL',  '-dFL d', {OUT => "d/\n"}, $slink_d, $unlink_d],

     # Test for a bug that was fixed in coreutils-4.5.4.
     ['sl-F-color', '-F --color=always d',
                                 {OUT => "$e\e[01;36md$e\@\n"},
                                  $slink_d, $unlink_d],
     ['sl-dF-color', '-dF --color=always d',
                                 {OUT => "$e\e[01;36md$e\@\n"},
                                  $slink_d, $unlink_d],

     # A listing with no output should have no color sequences at all.
     ['no-c-empty', '--color=always d', {OUT => ""}, $mkdir, $rmdir],
     # A listing with only regular files should have no color sequences at all.
     ['no-c-reg', '--color=always d', {OUT => "f\n"}, $mkdir_reg, $rmdir_reg],

     # Test for a bug fixed after coreutils-6.9.
     ['sl-target', '--color=always d',
      {OUT => "$e\e[01;34mX$e\n"}, $target, $target2],

     # Test for another bug fixed after coreutils-6.9.
     # This one bites only for a system/file system with d_type support.
     ['sl-dangle', '--color=always d',
      {OUT => "$e\e[40;31;01mX$e\n"},
      {PRE => sub {
                mkdir 'd',0755 or die "d: $!\n";
                symlink 'non-existent', 'd/X' or die "d/X: $!\n";
                push_ls_colors('or=40;31;01')
              }},
      {POST => sub {unlink 'd/X' or die "d/X: $!\n";
                    rmdir 'd' or die "d: $!\n";
                    restore_ls_colors; }},
     ],

     # Test for a bug fixed after coreutils-8.2.
     ['sl-dangle2', '-o --time-style=+:TIME: --color=always l',
      {OUT_SUBST => 's/.*:TIME: //'},
      {OUT => "l -> nowhere\n"},
      {PRE => sub {symlink 'nowhere', 'l' or die "l: $!\n";
                   push_ls_colors('ln=target')
       }},
      {POST => sub {unlink 'l' or die "l: $!\n";
                    restore_ls_colors; }},
     ],
     ['sl-dangle3', '-o --time-style=+:TIME: --color=always l',
      {OUT_SUBST => 's/.*:TIME: //'},
      {OUT => "$e\e[40ml$e -> \e[34mnowhere$e\n"},
      {PRE => sub {symlink 'nowhere', 'l' or die "l: $!\n";
                   push_ls_colors('ln=target:or=40:mi=34:')
       }},
      {POST => sub {unlink 'l' or die "l: $!\n";
                    restore_ls_colors; }},
     ],
     ['sl-dangle4', '-o --time-style=+:TIME: --color=always l',
      {OUT_SUBST => 's/.*:TIME: //'},
      {OUT => "$e\e[36ml$e -> \e[35mnowhere$e\n"},
      {PRE => sub {symlink 'nowhere', 'l' or die "l: $!\n";
                   push_ls_colors('ln=34:mi=35:or=36:')
       }},
      {POST => sub {unlink 'l' or die "l: $!\n";
                    restore_ls_colors; }},
     ],
     ['sl-dangle5', '-o --time-style=+:TIME: --color=always l',
      {OUT_SUBST => 's/.*:TIME: //'},
      {OUT => "$e\e[34ml$e -> \e[35mnowhere$e\n"},
      {PRE => sub {symlink 'nowhere', 'l' or die "l: $!\n";
                   push_ls_colors('ln=34:mi=35:')
       }},
      {POST => sub {unlink 'l' or die "l: $!\n";
                    restore_ls_colors; }},
     ],

     # Test for a bug fixed after coreutils-8.13
     # where 'argetm' was errenously printed for dangling links
     # when ln=target was used in LS_COLORS
     ['sl-dangle6', '-L --color=always d',
      {OUT => "s\n"},
      {PRE => sub {mkdir 'd',0755 or die "d: $!\n";
                   symlink 'dangle', 'd/s' or die "d/s: $!\n";
                   push_ls_colors('ln=target')
       }},
      {POST => sub {unlink 'd/s' or die "d/s: $!\n";
                    rmdir 'd' or die "d: $!\n";
                    restore_ls_colors; }},
      {ERR => "ls: cannot access 'd/s': No such file or directory\n"},
      {EXIT => 1}
     ],
     # Related to the above fix, is this case where
     # the code simulates "linkok".  In this case "linkmode"
     # should always be zero, and hence not trigger any
     # issues with type being set to C_LINK
     ['sl-dangle7', '--color=always d',
      {OUT => "$e\e[ms$e\n"},
      {PRE => sub {mkdir 'd',0755 or die "d: $!\n";
                   symlink 'dangle', 'd/s' or die "d/s: $!\n";
                   push_ls_colors('ln=target:or=:ex=:')
       }},
      {POST => sub {unlink 'd/s' or die "d/s: $!\n";
                    rmdir 'd' or die "d: $!\n";
                    restore_ls_colors; }},
     ],
     # Another case with simulated "linkok", that does
     # actually use the value of 'ln' from $LS_COLORS.
     # This path is not taken though when 'ln=target'.
     ['sl-dangle8', '--color=always s',
      {OUT => "$e\e[1;36ms$e\n"},
      {PRE => sub {symlink 'dangle', 's' or die "s: $!\n";
                   push_ls_colors('ln=1;36:or=:')
       }},
      {POST => sub {unlink 's' or die "s: $!\n";
                    restore_ls_colors; }},
     ],
     # The patch associated with sl-dangle[678] introduced a regression
     # that was fixed after coreutils-8.19.  This edge case triggers when
     # listing a dir containing dangling symlinks, but with orphans uncolored.
     # I.e., the same as the previous test, but listing the directory
     # rather than the symlink directly.
     ['sl-dangle9', '--color=always d',
      {OUT => "$e\e[1;36ms$e\n"},
      {PRE => sub {mkdir 'd',0755 or die "d: $!\n";
                   symlink 'dangle', 'd/s' or die "d/s: $!\n";
                   push_ls_colors('ln=1;36:or=:')
       }},
      {POST => sub {unlink 'd/s' or die "d/s: $!\n";
                    rmdir 'd' or die "d: $!\n";
                    restore_ls_colors; }},
     ],

     # Test for a bug that was introduced in coreutils-4.5.4; fixed in 4.5.5.
     # To demonstrate it, the file in question (with executable bit set)
     # must not be a command line argument.
     ['color-exe1', '--color=always j',
                                 {OUT => "$e\e[01;32md$e\n"},
                                  $exe_in_subdir, $remove_j],

     # From Stéphane Chazelas.
     ['no-a-isdir-b', 'no-dir d',
         {OUT => "d:\n"},
         {ERR => "ls: cannot access 'no-dir': No such file or directory\n"},
         $mkdir, $rmdir, {EXIT => 2}],

     ['recursive-2', '-R d', {OUT => "d:\ne\n\nd/e:\n"}, $mkdir2, $rmdir2],

     ['setuid-etc', '-1 -d --color=always owr owt setgid setuid sticky',
         {OUT =>
            "$e\e[34;42mowr$e\n"
            . "\e[30;42mowt$e\n"
            . "\e[30;43msetgid$e\n"
            . "\e[37;41msetuid$e\n"
            . "\e[37;44msticky$e\n"
         },

        {PRE => sub {
         push_ls_colors('ow=34;42:tw=30;42:sg=30;43:su=37;41:st=37;44'); }},
        {POST => sub {
         unlink qw(setuid setgid);
         foreach my $dir (qw(owr owt sticky)) {rmdir $dir}
         restore_ls_colors; }},
         ],

     # For 5.97 and earlier, --file-type acted like --indicator-style=slash.
     ['file-type', '--file-type d', {OUT => "s@\n"},
      $mkdir_d_slink, $rmdir_d_slink],

     # 7.1 had a regression in how -v -a ordered some files
     ['version-sort', '-v -A ' . join (' ', @v_files),
      {OUT => join ("\n", @v_files) . "\n"},
      {PRE => sub { mk_file @v_files }},
      {POST => sub { unlink @v_files }},
      ],

     # Test for the ls -1U bug fixed in coreutils-7.5.
     # It is triggered only with -1U and with two or more arguments,
     # at least one of which is a nonempty directory.
     ['multi-arg-U1', '-U1 d no-such',
      {OUT => "d:\nf\n"},
      {ERR_SUBST=>"s/ch':.*/ch':/"},
      {ERR => "$prog: cannot access 'no-such':\n"},
      $mkdir_reg,
      $rmdir_reg,
      {EXIT => 2},
     ],
    );

umask 022;

# Start with an unset LS_COLORS environment variable.
delete $ENV{LS_COLORS};

my $save_temps = $ENV{SAVE_TEMPS};
my $verbose = $ENV{VERBOSE};

setuid_setup;
my $fail = run_tests ($ME, $prog, \@Tests, $save_temps, $verbose);
$fail
  and exit 1;

# Be careful to use the just-build dircolors.
my $env = qx/dircolors -b/;
$env =~ s/^LS_COLORS=\'//;
$env =~ s/\';.*//sm;
$ENV{LS_COLORS} = $env;

setuid_setup;
$fail = run_tests ($ME, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
