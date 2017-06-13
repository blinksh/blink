'\" Copyright (C) 1998-2017 Free Software Foundation, Inc.
'\"
'\" This is free software.  You may redistribute copies of it under the terms
'\" of the GNU General Public License <http://www.gnu.org/licenses/gpl.html>.
'\" There is NO WARRANTY, to the extent permitted by law.
[NAME]
du \- estimate file space usage
[DESCRIPTION]
.\" Add any additional description here
[PATTERNS]
PATTERN is a shell pattern (not a regular expression).  The pattern
.BR ?
matches any one character, whereas
.BR *
matches any string (composed of zero, one or multiple characters).  For
example,
.BR *.o
will match any files whose names end in
.BR .o .
Therefore, the command
.IP
.B du --exclude=\(aq*.o\(aq
.PP
will skip all files and subdirectories ending in
.BR .o
(including the file
.BR .o
itself).
