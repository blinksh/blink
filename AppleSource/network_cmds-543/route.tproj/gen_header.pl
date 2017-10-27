#!/usr/local/bin/perl -n
# 
# Too run convert the keywords run the following command
#	gen_header.pl keywords > keywords.h

next if m/^#/;
next if m/^$/;
$line_no++;
chop;
$keyword = $_;
$upper = $keyword;
$upper =~ tr/a-z/A-Z/;

printf "#define\tK_%s\t%d\n\t{\"%s\", K_%s},\n", 
    $upper, $line_no, $keyword, $upper;
