[NAME]
runcon \- run command with specified security context
[DESCRIPTION]
Run COMMAND with completely-specified CONTEXT, or with current or
transitioned security context modified by one or more of LEVEL,
ROLE, TYPE, and USER.
.PP
If none of \fI-c\fR, \fI-t\fR, \fI-u\fR, \fI-r\fR, or \fI-l\fR, is specified,
the first argument is used as the complete context.  Any additional
arguments after \fICOMMAND\fR are interpreted as arguments to the
command.
.PP
Note that only carefully-chosen contexts are likely to successfully
run.
