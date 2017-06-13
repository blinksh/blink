/* date - print or set the system date and time
   Copyright (C) 1989-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.

   David MacKenzie <djm@gnu.ai.mit.edu> */

#include <config.h>
#include <stdio.h>
#include <getopt.h>
#include <sys/types.h>
#if HAVE_LANGINFO_CODESET
# include <langinfo.h>
#endif

#include "system.h"
#include "argmatch.h"
#include "die.h"
#include "error.h"
#include "parse-datetime.h"
#include "posixtm.h"
#include "quote.h"
#include "stat-time.h"
#include "fprintftime.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "date"

#define AUTHORS proper_name ("David MacKenzie")

static bool show_date (const char *, struct timespec, timezone_t);

enum Time_spec
{
  /* Display only the date.  */
  TIME_SPEC_DATE,
  /* Display date, hours, minutes, and seconds.  */
  TIME_SPEC_SECONDS,
  /* Similar, but display nanoseconds. */
  TIME_SPEC_NS,

  /* Put these last, since they aren't valid for --rfc-3339.  */

  /* Display date and hour.  */
  TIME_SPEC_HOURS,
  /* Display date, hours, and minutes.  */
  TIME_SPEC_MINUTES
};

static char const *const time_spec_string[] =
{
  /* Put "hours" and "minutes" first, since they aren't valid for
     --rfc-3339.  */
  "hours", "minutes",
  "date", "seconds", "ns", NULL
};
static enum Time_spec const time_spec[] =
{
  TIME_SPEC_HOURS, TIME_SPEC_MINUTES,
  TIME_SPEC_DATE, TIME_SPEC_SECONDS, TIME_SPEC_NS
};
ARGMATCH_VERIFY (time_spec_string, time_spec);

/* A format suitable for Internet RFCs 5322, 2822, and 822.  */
static char const rfc_email_format[] = "%a, %d %b %Y %H:%M:%S %z";

/* For long options that have no equivalent short option, use a
   non-character as a pseudo short option, starting with CHAR_MAX + 1.  */
enum
{
  RFC_3339_OPTION = CHAR_MAX + 1,
  DEBUG_DATE_PARSING
};

static char const short_options[] = "d:f:I::r:Rs:u";

static struct option const long_options[] =
{
  {"date", required_argument, NULL, 'd'},
  {"debug", no_argument, NULL, DEBUG_DATE_PARSING},
  {"file", required_argument, NULL, 'f'},
  {"iso-8601", optional_argument, NULL, 'I'},
  {"reference", required_argument, NULL, 'r'},
  {"rfc-email", no_argument, NULL, 'R'},
  {"rfc-822", no_argument, NULL, 'R'},
  {"rfc-2822", no_argument, NULL, 'R'},
  {"rfc-3339", required_argument, NULL, RFC_3339_OPTION},
  {"set", required_argument, NULL, 's'},
  {"uct", no_argument, NULL, 'u'},
  {"utc", no_argument, NULL, 'u'},
  {"universal", no_argument, NULL, 'u'},
  {GETOPT_HELP_OPTION_DECL},
  {GETOPT_VERSION_OPTION_DECL},
  {NULL, 0, NULL, 0}
};

/* flags for parse_datetime2 */
static unsigned int parse_datetime_flags;

#if LOCALTIME_CACHE
# define TZSET tzset ()
#else
# define TZSET /* empty */
#endif

#ifdef _DATE_FMT
# define DATE_FMT_LANGINFO() nl_langinfo (_DATE_FMT)
#else
# define DATE_FMT_LANGINFO() ""
#endif

void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("\
Usage: %s [OPTION]... [+FORMAT]\n\
  or:  %s [-u|--utc|--universal] [MMDDhhmm[[CC]YY][.ss]]\n\
"),
              program_name, program_name);
      fputs (_("\
Display the current time in the given FORMAT, or set the system date.\n\
"), stdout);

      emit_mandatory_arg_note ();

      fputs (_("\
  -d, --date=STRING          display time described by STRING, not 'now'\n\
"), stdout);
      fputs (_("\
      --debug                annotate the parsed date,\n\
                              and warn about questionable usage to stderr\n\
"), stdout);
      fputs (_("\
  -f, --file=DATEFILE        like --date; once for each line of DATEFILE\n\
"), stdout);
      fputs (_("\
  -I[FMT], --iso-8601[=FMT]  output date/time in ISO 8601 format.\n\
                               FMT='date' for date only (the default),\n\
                               'hours', 'minutes', 'seconds', or 'ns'\n\
                               for date and time to the indicated precision.\n\
                               Example: 2006-08-14T02:34:56-06:00\n\
"), stdout);
      fputs (_("\
  -R, --rfc-email            output date and time in RFC 5322 format.\n\
                               Example: Mon, 14 Aug 2006 02:34:56 -0600\n\
"), stdout);
      fputs (_("\
      --rfc-3339=FMT         output date/time in RFC 3339 format.\n\
                               FMT='date', 'seconds', or 'ns'\n\
                               for date and time to the indicated precision.\n\
                               Example: 2006-08-14 02:34:56-06:00\n\
"), stdout);
      fputs (_("\
  -r, --reference=FILE       display the last modification time of FILE\n\
"), stdout);
      fputs (_("\
  -s, --set=STRING           set time described by STRING\n\
  -u, --utc, --universal     print or set Coordinated Universal Time (UTC)\n\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      fputs (_("\
\n\
FORMAT controls the output.  Interpreted sequences are:\n\
\n\
  %%   a literal %\n\
  %a   locale's abbreviated weekday name (e.g., Sun)\n\
"), stdout);
      fputs (_("\
  %A   locale's full weekday name (e.g., Sunday)\n\
  %b   locale's abbreviated month name (e.g., Jan)\n\
  %B   locale's full month name (e.g., January)\n\
  %c   locale's date and time (e.g., Thu Mar  3 23:05:25 2005)\n\
"), stdout);
      fputs (_("\
  %C   century; like %Y, except omit last two digits (e.g., 20)\n\
  %d   day of month (e.g., 01)\n\
  %D   date; same as %m/%d/%y\n\
  %e   day of month, space padded; same as %_d\n\
"), stdout);
      fputs (_("\
  %F   full date; same as %Y-%m-%d\n\
  %g   last two digits of year of ISO week number (see %G)\n\
  %G   year of ISO week number (see %V); normally useful only with %V\n\
"), stdout);
      fputs (_("\
  %h   same as %b\n\
  %H   hour (00..23)\n\
  %I   hour (01..12)\n\
  %j   day of year (001..366)\n\
"), stdout);
      fputs (_("\
  %k   hour, space padded ( 0..23); same as %_H\n\
  %l   hour, space padded ( 1..12); same as %_I\n\
  %m   month (01..12)\n\
  %M   minute (00..59)\n\
"), stdout);
      fputs (_("\
  %n   a newline\n\
  %N   nanoseconds (000000000..999999999)\n\
  %p   locale's equivalent of either AM or PM; blank if not known\n\
  %P   like %p, but lower case\n\
  %q   quarter of year (1..4)\n\
  %r   locale's 12-hour clock time (e.g., 11:11:04 PM)\n\
  %R   24-hour hour and minute; same as %H:%M\n\
  %s   seconds since 1970-01-01 00:00:00 UTC\n\
"), stdout);
      fputs (_("\
  %S   second (00..60)\n\
  %t   a tab\n\
  %T   time; same as %H:%M:%S\n\
  %u   day of week (1..7); 1 is Monday\n\
"), stdout);
      fputs (_("\
  %U   week number of year, with Sunday as first day of week (00..53)\n\
  %V   ISO week number, with Monday as first day of week (01..53)\n\
  %w   day of week (0..6); 0 is Sunday\n\
  %W   week number of year, with Monday as first day of week (00..53)\n\
"), stdout);
      fputs (_("\
  %x   locale's date representation (e.g., 12/31/99)\n\
  %X   locale's time representation (e.g., 23:13:48)\n\
  %y   last two digits of year (00..99)\n\
  %Y   year\n\
"), stdout);
      fputs (_("\
  %z   +hhmm numeric time zone (e.g., -0400)\n\
  %:z  +hh:mm numeric time zone (e.g., -04:00)\n\
  %::z  +hh:mm:ss numeric time zone (e.g., -04:00:00)\n\
  %:::z  numeric time zone with : to necessary precision (e.g., -04, +05:30)\n\
  %Z   alphabetic time zone abbreviation (e.g., EDT)\n\
\n\
By default, date pads numeric fields with zeroes.\n\
"), stdout);
      fputs (_("\
The following optional flags may follow '%':\n\
\n\
  -  (hyphen) do not pad the field\n\
  _  (underscore) pad with spaces\n\
  0  (zero) pad with zeros\n\
  ^  use upper case if possible\n\
  #  use opposite case if possible\n\
"), stdout);
      fputs (_("\
\n\
After any flags comes an optional field width, as a decimal number;\n\
then an optional modifier, which is either\n\
E to use the locale's alternate representations if available, or\n\
O to use the locale's alternate numeric symbols if available.\n\
"), stdout);
      fputs (_("\
\n\
Examples:\n\
Convert seconds since the epoch (1970-01-01 UTC) to a date\n\
  $ date --date='@2147483647'\n\
\n\
Show the time on the west coast of the US (use tzselect(1) to find TZ)\n\
  $ TZ='America/Los_Angeles' date\n\
\n\
Show the local time for 9AM next Friday on the west coast of the US\n\
  $ date --date='TZ=\"America/Los_Angeles\" 09:00 next Fri'\n\
"), stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

/* Parse each line in INPUT_FILENAME as with --date and display each
   resulting time and date.  If the file cannot be opened, tell why
   then exit.  Issue a diagnostic for any lines that cannot be parsed.
   Return true if successful.  */

static bool
batch_convert (const char *input_filename, const char *format,
               timezone_t tz, char const *tzstring)
{
  bool ok;
  FILE *in_stream;
  char *line;
  size_t buflen;
  struct timespec when;

  if (STREQ (input_filename, "-"))
    {
      input_filename = _("standard input");
      in_stream = stdin;
    }
  else
    {
      in_stream = fopen (input_filename, "r");
      if (in_stream == NULL)
        {
          die (EXIT_FAILURE, errno, "%s", quotef (input_filename));
        }
    }

  line = NULL;
  buflen = 0;
  ok = true;
  while (1)
    {
      ssize_t line_length = getline (&line, &buflen, in_stream);
      if (line_length < 0)
        {
          /* FIXME: detect/handle error here.  */
          break;
        }

      if (! parse_datetime2 (&when, line, NULL,
                             parse_datetime_flags, tz, tzstring))
        {
          if (line[line_length - 1] == '\n')
            line[line_length - 1] = '\0';
          error (0, 0, _("invalid date %s"), quote (line));
          ok = false;
        }
      else
        {
          ok &= show_date (format, when, tz);
        }
    }

  if (fclose (in_stream) == EOF)
    die (EXIT_FAILURE, errno, "%s", quotef (input_filename));

  free (line);

  return ok;
}

int
main (int argc, char **argv)
{
  int optc;
  const char *datestr = NULL;
  const char *set_datestr = NULL;
  struct timespec when;
  bool set_date = false;
  char const *format = NULL;
  char *batch_file = NULL;
  char *reference = NULL;
  struct stat refstats;
  bool ok;
  int option_specified_date;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  while ((optc = getopt_long (argc, argv, short_options, long_options, NULL))
         != -1)
    {
      char const *new_format = NULL;

      switch (optc)
        {
        case 'd':
          datestr = optarg;
          break;
        case DEBUG_DATE_PARSING:
          parse_datetime_flags |= PARSE_DATETIME_DEBUG;
          break;
        case 'f':
          batch_file = optarg;
          break;
        case RFC_3339_OPTION:
          {
            static char const rfc_3339_format[][32] =
              {
                "%Y-%m-%d",
                "%Y-%m-%d %H:%M:%S%:z",
                "%Y-%m-%d %H:%M:%S.%N%:z"
              };
            enum Time_spec i =
              XARGMATCH ("--rfc-3339", optarg,
                         time_spec_string + 2, time_spec + 2);
            new_format = rfc_3339_format[i];
            break;
          }
        case 'I':
          {
            static char const iso_8601_format[][32] =
              {
                "%Y-%m-%d",
                "%Y-%m-%dT%H:%M:%S%:z",
                "%Y-%m-%dT%H:%M:%S,%N%:z",
                "%Y-%m-%dT%H%:z",
                "%Y-%m-%dT%H:%M%:z"
              };
            enum Time_spec i =
              (optarg
               ? XARGMATCH ("--iso-8601", optarg, time_spec_string, time_spec)
               : TIME_SPEC_DATE);
            new_format = iso_8601_format[i];
            break;
          }
        case 'r':
          reference = optarg;
          break;
        case 'R':
          new_format = rfc_email_format;
          break;
        case 's':
          set_datestr = optarg;
          set_date = true;
          break;
        case 'u':
          /* POSIX says that 'date -u' is equivalent to setting the TZ
             environment variable, so this option should do nothing other
             than setting TZ.  */
          if (putenv (bad_cast ("TZ=UTC0")) != 0)
            xalloc_die ();
          TZSET;
          break;
        case_GETOPT_HELP_CHAR;
        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);
        default:
          usage (EXIT_FAILURE);
        }

      if (new_format)
        {
          if (format)
            die (EXIT_FAILURE, 0, _("multiple output formats specified"));
          format = new_format;
        }
    }

  option_specified_date = ((datestr ? 1 : 0)
                           + (batch_file ? 1 : 0)
                           + (reference ? 1 : 0));

  if (option_specified_date > 1)
    {
      error (0, 0,
        _("the options to specify dates for printing are mutually exclusive"));
      usage (EXIT_FAILURE);
    }

  if (set_date && option_specified_date)
    {
      error (0, 0,
          _("the options to print and set the time may not be used together"));
      usage (EXIT_FAILURE);
    }

  if (optind < argc)
    {
      if (optind + 1 < argc)
        {
          error (0, 0, _("extra operand %s"), quote (argv[optind + 1]));
          usage (EXIT_FAILURE);
        }

      if (argv[optind][0] == '+')
        {
          if (format)
            die (EXIT_FAILURE, 0, _("multiple output formats specified"));
          format = argv[optind++] + 1;
        }
      else if (set_date || option_specified_date)
        {
          error (0, 0,
                 _("the argument %s lacks a leading '+';\n"
                   "when using an option to specify date(s), any non-option\n"
                   "argument must be a format string beginning with '+'"),
                 quote (argv[optind]));
          usage (EXIT_FAILURE);
        }
    }

  if (!format)
    {
      format = DATE_FMT_LANGINFO ();
      if (! *format)
        {
          /* Do not wrap the following literal format string with _(...).
             For example, suppose LC_ALL is unset, LC_TIME=POSIX,
             and LANG="ko_KR".  In that case, POSIX says that LC_TIME
             determines the format and contents of date and time strings
             written by date, which means "date" must generate output
             using the POSIX locale; but adding _() would cause "date"
             to use a Korean translation of the format.  */
          format = "%a %b %e %H:%M:%S %Z %Y";
        }
    }

  char const *tzstring = getenv ("TZ");
  timezone_t tz = tzalloc (tzstring);

  if (batch_file != NULL)
    ok = batch_convert (batch_file, format, tz, tzstring);
  else
    {
      bool valid_date = true;
      ok = true;

      if (!option_specified_date && !set_date)
        {
          if (optind < argc)
            {
              /* Prepare to set system clock to the specified date/time
                 given in the POSIX-format.  */
              set_date = true;
              datestr = argv[optind];
              valid_date = posixtime (&when.tv_sec,
                                      datestr,
                                      (PDS_TRAILING_YEAR
                                       | PDS_CENTURY | PDS_SECONDS));
              when.tv_nsec = 0; /* FIXME: posixtime should set this.  */
            }
          else
            {
              /* Prepare to print the current date/time.  */
              gettime (&when);
            }
        }
      else
        {
          /* (option_specified_date || set_date) */
          if (reference != NULL)
            {
              if (stat (reference, &refstats) != 0)
                die (EXIT_FAILURE, errno, "%s", quotef (reference));
              when = get_stat_mtime (&refstats);
            }
          else
            {
              if (set_datestr)
                datestr = set_datestr;
              valid_date = parse_datetime2 (&when, datestr, NULL,
                                            parse_datetime_flags,
                                            tz, tzstring);
            }
        }

      if (! valid_date)
        die (EXIT_FAILURE, 0, _("invalid date %s"), quote (datestr));

      if (set_date)
        {
          /* Set the system clock to the specified date, then regardless of
             the success of that operation, format and print that date.  */
          if (settime (&when) != 0)
            {
              error (0, errno, _("cannot set date"));
              ok = false;
            }
        }

      ok &= show_date (format, when, tz);
    }

  IF_LINT (tzfree (tz));

  return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}

/* Display the date and/or time in WHEN according to the format specified
   in FORMAT, followed by a newline.  Return true if successful.  */

static bool
show_date (const char *format, struct timespec when, timezone_t tz)
{
  struct tm tm;

  if (localtime_rz (tz, &when.tv_sec, &tm))
    {
      if (format == rfc_email_format)
        setlocale (LC_TIME, "C");
      fprintftime (stdout, format, &tm, tz, when.tv_nsec);
      if (format == rfc_email_format)
        setlocale (LC_TIME, "");
      fputc ('\n', stdout);
      return true;
    }
  else
    {
      char buf[INT_BUFSIZE_BOUND (intmax_t)];
      error (0, 0, _("time %s is out of range"),
             quote (timetostr (when.tv_sec, buf)));
      return false;
    }
}
