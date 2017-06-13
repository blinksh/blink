'\" Copyright (C) 1998-2017 Free Software Foundation, Inc.
'\"
'\" This is free software.  You may redistribute copies of it under the terms
'\" of the GNU General Public License <http://www.gnu.org/licenses/gpl.html>.
'\" There is NO WARRANTY, to the extent permitted by law.
[NAME]
rm \- remove files or directories
[DESCRIPTION]
This manual page
documents the GNU version of
.BR rm .
.B rm
removes each specified file.  By default, it does not remove
directories.
.P
If the \fI\-I\fR or \fI\-\-interactive\=once\fR option is given,
and there are more than three files or the \fI\-r\fR, \fI\-R\fR,
or \fI\-\-recursive\fR are given, then
.B rm
prompts the user for whether to proceed with the entire operation.  If
the response is not affirmative, the entire command is aborted.
.P
Otherwise, if a file is unwritable, standard input is a terminal, and
the \fI\-f\fR or \fI\-\-force\fR option is not given, or the
\fI\-i\fR or \fI\-\-interactive\=always\fR option is given,
.B rm
prompts the user for whether to remove the file.  If the response is
not affirmative, the file is skipped.
.SH OPTIONS
[SEE ALSO]
unlink(1), unlink(2), chattr(1), shred(1)
