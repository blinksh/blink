%{
/* Parse a string into an internal timestamp.

   Copyright (C) 1999-2000, 2002-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* Originally written by Steven M. Bellovin <smb@research.att.com> while
   at the University of North Carolina at Chapel Hill.  Later tweaked by
   a couple of people on Usenet.  Completely overhauled by Rich $alz
   <rsalz@bbn.com> and Jim Berets <jberets@bbn.com> in August, 1990.

   Modified by Paul Eggert <eggert@twinsun.com> in August 1999 to do
   the right thing about local DST.  Also modified by Paul Eggert
   <eggert@cs.ucla.edu> in February 2004 to support
   nanosecond-resolution timestamps, and in October 2004 to support
   TZ strings in dates.  */

/* FIXME: Check for arithmetic overflow in all cases, not just
   some of them.  */

#include <config.h>

#include "parse-datetime.h"

#include "intprops.h"
#include "timespec.h"
#include "verify.h"
#include "strftime.h"

/* There's no need to extend the stack, so there's no need to involve
   alloca.  */
#define YYSTACK_USE_ALLOCA 0

/* Tell Bison how much stack space is needed.  20 should be plenty for
   this grammar, which is not right recursive.  Beware setting it too
   high, since that might cause problems on machines whose
   implementations have lame stack-overflow checking.  */
#define YYMAXDEPTH 20
#define YYINITDEPTH YYMAXDEPTH

/* Since the code of parse-datetime.y is not included in the Emacs executable
   itself, there is no need to #define static in this file.  Even if
   the code were included in the Emacs executable, it probably
   wouldn't do any harm to #undef it here; this will only cause
   problems if we try to write to a static variable, which I don't
   think this code needs to do.  */
#ifdef emacs
# undef static
#endif

#include <inttypes.h>
#include <c-ctype.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "gettext.h"

#define _(str) gettext (str)

/* Bison's skeleton tests _STDLIB_H, while some stdlib.h headers
   use _STDLIB_H_ as witness.  Map the latter to the one bison uses.  */
/* FIXME: this is temporary.  Remove when we have a mechanism to ensure
   that the version we're using is fixed, too.  */
#ifdef _STDLIB_H_
# undef _STDLIB_H
# define _STDLIB_H 1
#endif

/* ISDIGIT differs from isdigit, as follows:
   - Its arg may be any int or unsigned int; it need not be an unsigned char
     or EOF.
   - It's typically faster.
   POSIX says that only '0' through '9' are digits.  Prefer ISDIGIT to
   isdigit unless it's important to use the locale's definition
   of "digit" even when the host does not conform to POSIX.  */
#define ISDIGIT(c) ((unsigned int) (c) - '0' <= 9)

/* Shift A right by B bits portably, by dividing A by 2**B and
   truncating towards minus infinity.  A and B should be free of side
   effects, and B should be in the range 0 <= B <= INT_BITS - 2, where
   INT_BITS is the number of useful bits in an int.  GNU code can
   assume that INT_BITS is at least 32.

   ISO C99 says that A >> B is implementation-defined if A < 0.  Some
   implementations (e.g., UNICOS 9.0 on a Cray Y-MP EL) don't shift
   right in the usual way when A < 0, so SHR falls back on division if
   ordinary A >> B doesn't seem to be the usual signed shift.  */
#define SHR(a, b)       \
  (-1 >> 1 == -1        \
   ? (a) >> (b)         \
   : (a) / (1 << (b)) - ((a) % (1 << (b)) < 0))

#define EPOCH_YEAR 1970
#define TM_YEAR_BASE 1900

#define HOUR(x) ((x) * 60)

#define STREQ(a, b) (strcmp (a, b) == 0)

/* long_time_t is a signed integer type that contains all time_t values.  */
verify (TYPE_IS_INTEGER (time_t));
#if TIME_T_FITS_IN_LONG_INT
typedef long int long_time_t;
#else
typedef time_t long_time_t;
#endif

/* Convert a possibly-signed character to an unsigned character.  This is
   a bit safer than casting to unsigned char, since it catches some type
   errors that the cast doesn't.  */
static unsigned char to_uchar (char ch) { return ch; }

static void
dbg_printf (const char *msg,...)
{
  va_list args;
  /* TODO: use gnulib's 'program_name' instead? */
  fputs ("date: ", stderr);

  va_start (args, msg);
  vfprintf (stderr, msg, args);
  va_end (args);
}



/* Lots of this code assumes time_t and time_t-like values fit into
   long_time_t.  */
verify (TYPE_MINIMUM (long_time_t) <= TYPE_MINIMUM (time_t)
        && TYPE_MAXIMUM (time_t) <= TYPE_MAXIMUM (long_time_t));

/* FIXME: It also assumes that signed integer overflow silently wraps around,
   but this is not true any more with recent versions of GCC 4.  */

/* An integer value, and the number of digits in its textual
   representation.  */
typedef struct
{
  bool negative;
  long int value;
  size_t digits;
} textint;

/* An entry in the lexical lookup table.  */
typedef struct
{
  char const *name;
  int type;
  int value;
} table;

/* Meridian: am, pm, or 24-hour style.  */
enum { MERam, MERpm, MER24 };

enum { BILLION = 1000000000, LOG10_BILLION = 9 };

/* Relative times.  */
typedef struct
{
  /* Relative year, month, day, hour, minutes, seconds, and nanoseconds.  */
  long int year;
  long int month;
  long int day;
  long int hour;
  long int minutes;
  long_time_t seconds;
  long int ns;
} relative_time;

#if HAVE_COMPOUND_LITERALS
# define RELATIVE_TIME_0 ((relative_time) { 0, 0, 0, 0, 0, 0, 0 })
#else
static relative_time const RELATIVE_TIME_0;
#endif

/* Information passed to and from the parser.  */
typedef struct
{
  /* The input string remaining to be parsed. */
  const char *input;

  /* N, if this is the Nth Tuesday.  */
  long int day_ordinal;

  /* Day of week; Sunday is 0.  */
  int day_number;

  /* tm_isdst flag for the local zone.  */
  int local_isdst;

  /* Time zone, in minutes east of UTC.  */
  long int time_zone;

  /* Style used for time.  */
  int meridian;

  /* Gregorian year, month, day, hour, minutes, seconds, and nanoseconds.  */
  textint year;
  long int month;
  long int day;
  long int hour;
  long int minutes;
  struct timespec seconds; /* includes nanoseconds */

  /* Relative year, month, day, hour, minutes, seconds, and nanoseconds.  */
  relative_time rel;

  /* Presence or counts of nonterminals of various flavors parsed so far.  */
  bool timespec_seen;
  bool rels_seen;
  size_t dates_seen;
  size_t days_seen;
  size_t local_zones_seen;
  size_t dsts_seen;
  size_t times_seen;
  size_t zones_seen;
  size_t year_seen;

  /* if true, print debugging output to stderr */
  bool parse_datetime_debug;

  /* which of the 'seen' parts has been printed when debugging */
  size_t debug_dates_seen;
  size_t debug_days_seen;
  size_t debug_local_zones_seen;
  size_t debug_dsts_seen;
  size_t debug_times_seen;
  size_t debug_zones_seen;
  size_t debug_year_seen;

  /* true if the user specified explicit ordinal day value, */
  bool debug_ordinal_day_seen;

  /* the default input timezone, set by TZ value */
  long int debug_default_input_timezone;

  /* Table of local time zone abbreviations, terminated by a null entry.  */
  table local_time_zone_table[3];
} parser_control;

union YYSTYPE;
static int yylex (union YYSTYPE *, parser_control *);
static int yyerror (parser_control const *, char const *);
static long int time_zone_hhmm (parser_control *, textint, long int);

/* Extract into *PC any date and time info from a string of digits
   of the form e.g., YYYYMMDD, YYMMDD, HHMM, HH (and sometimes YYY,
   YYYY, ...).  */
static void
digits_to_date_time (parser_control *pc, textint text_int)
{
  if (pc->dates_seen && ! pc->year.digits
      && ! pc->rels_seen && (pc->times_seen || 2 < text_int.digits))
    {
      pc->year_seen++;
      pc->year = text_int;
    }
  else
    {
      if (4 < text_int.digits)
        {
          pc->dates_seen++;
          pc->day = text_int.value % 100;
          pc->month = (text_int.value / 100) % 100;
          pc->year.value = text_int.value / 10000;
          pc->year.digits = text_int.digits - 4;
        }
      else
        {
          pc->times_seen++;
          if (text_int.digits <= 2)
            {
              pc->hour = text_int.value;
              pc->minutes = 0;
            }
          else
            {
              pc->hour = text_int.value / 100;
              pc->minutes = text_int.value % 100;
            }
          pc->seconds.tv_sec = 0;
          pc->seconds.tv_nsec = 0;
          pc->meridian = MER24;
        }
    }
}

/* Increment PC->rel by FACTOR * REL (FACTOR is 1 or -1).  */
static void
apply_relative_time (parser_control *pc, relative_time rel, int factor)
{
  pc->rel.ns += factor * rel.ns;
  pc->rel.seconds += factor * rel.seconds;
  pc->rel.minutes += factor * rel.minutes;
  pc->rel.hour += factor * rel.hour;
  pc->rel.day += factor * rel.day;
  pc->rel.month += factor * rel.month;
  pc->rel.year += factor * rel.year;
  pc->rels_seen = true;
}

/* Set PC-> hour, minutes, seconds and nanoseconds members from arguments.  */
static void
set_hhmmss (parser_control *pc, long int hour, long int minutes,
            time_t sec, long int nsec)
{
  pc->hour = hour;
  pc->minutes = minutes;
  pc->seconds.tv_sec = sec;
  pc->seconds.tv_nsec = nsec;
}

/* returns a textual representation of the day ordinal/number values
   in the parser_control struct (e.g. 'last wed', 'this tues', 'thu') */
static const char*
str_days (parser_control *pc, char* /*output*/ buffer, size_t n)
{
  /* TODO: use the  relative_time_table[] for reverse lookup */
  static const char* ordinal_values[] = {
     "last",
     "this",
     "next/first",
     "(SECOND)", /* SECOND is commented out in relative_time_table[] */
     "third",
     "fourth",
     "fifth",
     "sixth",
     "seventh",
     "eight",
     "ninth",
     "tenth",
     "eleventh",
     "twelfth"};

  static const char* days_values[] = {
     "Sun",
     "Mon",
     "Tue",
     "Wed",
     "Thu",
     "Fri",
     "Sat"
    };

  /* don't add an ordinal prefix if the user didn't specify it
     (e.g., "this wed" vs "wed") */
  if (pc->debug_ordinal_day_seen)
    {
      /* use word description of possible (e.g. -1 = last, 3 = third) */
      if (pc->day_ordinal>=-1 && pc->day_ordinal <=12)
        {
          strncpy (buffer, ordinal_values[ pc->day_ordinal+1 ], n);
          buffer[n-1]='\0';
        }
      else
        {
          snprintf (buffer,n,"%ld",pc->day_ordinal);
        }
    }
  else
    {
      buffer[0] = '\0';
    }

  /* Add the day name */
  if (pc->day_number>=0 && pc->day_number<=6)
    {
      size_t l = strlen (buffer);
      if (l>0)
        {
          strncat (buffer," ",n-l);
          ++l;
        }
      strncat (buffer,days_values[pc->day_number],n-l);
    }
  else
    {
      /* invalid day_number value - should never happen */
    }
  return buffer;
}

/* debugging: print the current time in the parser_control structure.
   The parser will increment "*_seen" members for those which were parsed.
   This function will print only newly seen parts. */
static void
debug_print_current_time (const char* item, parser_control *pc)
{
  char tmp[100] = {0};
  int space = 0; /* if true, add space delimiter */

  if (!pc->parse_datetime_debug)
    return;

  /* no newline, more items printed below */
  dbg_printf (_("parsed %s part: "), item);

  if (pc->dates_seen != pc->debug_dates_seen)
    {
      /*TODO: use pc->year.negative? */
      fprintf (stderr,"(Y-M-D) %04ld-%02ld-%02ld",
              pc->year.value, pc->month, pc->day);
      pc->debug_dates_seen = pc->dates_seen;
      space = 1;
    }

  if (pc->year_seen != pc->debug_year_seen)
    {
      if (space)
        fputc (' ',stderr);
      fprintf (stderr, _("year: %04ld"), pc->year.value);

      pc->debug_year_seen = pc->year_seen;
      space = 1;
    }

  if (pc->times_seen != pc->debug_times_seen)
    {
      if (space)
        fputc (' ',stderr);
      fprintf (stderr,"%02ld:%02ld:%02ld",
              pc->hour, pc->minutes, pc->seconds.tv_sec);
      if (pc->seconds.tv_nsec!=0)
        fprintf (stderr,"%09ld", pc->seconds.tv_nsec);
      if (pc->meridian==MERpm)
        fputs ("pm",stderr);

      pc->debug_times_seen = pc->times_seen;
      space = 1;
    }

  if (pc->days_seen != pc->debug_days_seen)
    {
      if (space)
        fputc (' ',stderr);
      fprintf (stderr,_("%s (day ordinal=%ld number=%d)"),
              str_days (pc,tmp,sizeof (tmp)),
              pc->day_ordinal, pc->day_number);
      pc->debug_days_seen = pc->days_seen ;
      space = 1;
    }

  /* local zone strings only change the DST settings,
     not the timezone value. If seen, inform about the DST.
     its value (0 or 1) will be printed in the next 'if' block */
  if (pc->local_zones_seen != pc->debug_local_zones_seen)
    {
      if (space)
        fputc (' ',stderr);
      fputs ( (pc->dsts_seen == pc->debug_dsts_seen)?
              _("DST unchanged"):_("DST changed:"),
              stderr);
      pc->debug_local_zones_seen = pc->local_zones_seen;
      space = 1;
    }

  if (pc->dsts_seen != pc->debug_dsts_seen)
    {
      if (space)
        fputc (' ',stderr);
      fprintf (stderr,_("is-dst=%d"), pc->local_isdst);
      pc->dsts_seen = pc->debug_dsts_seen;
      space = 1;
    }

  /* TODO: fix incorrect display of EST=2:08h? */
  if (pc->zones_seen != pc->debug_zones_seen)
    {
      if (space)
        fputc (' ',stderr);
      fprintf (stderr,_("TZ=%+03d:%02d"), (int)(pc->time_zone/60),
              abs ((int)pc->time_zone%60));
      pc->debug_zones_seen = pc->zones_seen;
      space = 1;
    }

  if (pc->timespec_seen)
    {
      if (space)
        fputc (' ',stderr);
      fprintf (stderr,_("number of seconds: %ld"), pc->seconds.tv_sec);
    }

  fputc ('\n', stderr);
}

/* debugging: print the current relative values. */
static void
debug_print_relative_time (const char* item, const parser_control *pc)
{
  int space = 0; /* if true, add space delimiter */

  if (!pc->parse_datetime_debug)
    return;

  /* no newline, more items printed below */
  dbg_printf (_("parsed %s part: "), item);

  if (pc->rel.year==0 && pc->rel.month==0 && pc->rel.day==0
      && pc->rel.hour==0 && pc->rel.minutes==00 && pc->rel.seconds == 0
      && pc->rel.ns==0)
    {
      /* Special case: relative time of this/today/now */
      fputs (_("today/this/now\n"),stderr);
      return ;
    }

#define PRINT_REL_PART(x,name)                          \
  do {                                                  \
    if ( (pc->rel.x) != 0 )                             \
      {                                                 \
        if (space)                                      \
          fputc (' ',stderr);                           \
        fprintf (stderr,"%+ld %s", pc->rel.x, name);    \
        space = 1;                                      \
      }                                                 \
  } while (0)

  PRINT_REL_PART (year,"year(s)");
  PRINT_REL_PART (month,"month(s)");
  PRINT_REL_PART (day,"day(s)");
  PRINT_REL_PART (hour,"hour(s)");
  PRINT_REL_PART (minutes,"minutes");
  PRINT_REL_PART (seconds,"seconds");
  PRINT_REL_PART (ns,"nanoseconds");

  fputc ('\n',stderr);
}



%}

/* We want a reentrant parser, even if the TZ manipulation and the calls to
   localtime and gmtime are not reentrant.  */
%pure-parser
%parse-param { parser_control *pc }
%lex-param { parser_control *pc }

/* This grammar has 31 shift/reduce conflicts. */
%expect 31

%union
{
  long int intval;
  textint textintval;
  struct timespec timespec;
  relative_time rel;
}

%token <intval> tAGO
%token tDST

%token tYEAR_UNIT tMONTH_UNIT tHOUR_UNIT tMINUTE_UNIT tSEC_UNIT
%token <intval> tDAY_UNIT tDAY_SHIFT

%token <intval> tDAY tDAYZONE tLOCAL_ZONE tMERIDIAN
%token <intval> tMONTH tORDINAL tZONE

%token <textintval> tSNUMBER tUNUMBER
%token <timespec> tSDECIMAL_NUMBER tUDECIMAL_NUMBER

%type <intval> o_colon_minutes
%type <timespec> seconds signed_seconds unsigned_seconds

%type <rel> relunit relunit_snumber dayshift

%%

spec:
    timespec
  | items
  ;

timespec:
    '@' seconds
      {
        pc->seconds = $2;
        pc->timespec_seen = true;
        debug_print_current_time (_("number of seconds"), pc);
      }
  ;

items:
    /* empty */
  | items item
  ;

item:
    datetime
      {
        pc->times_seen++; pc->dates_seen++;
        debug_print_current_time (_("datetime"), pc);
      }
  | time
      {
        pc->times_seen++;
        debug_print_current_time (_("time"), pc);
      }
  | local_zone
      {
        pc->local_zones_seen++;
        debug_print_current_time (_("local_zone"), pc);
      }
  | zone
      {
        pc->zones_seen++;
        debug_print_current_time (_("zone"), pc);
      }
  | date
      {
        pc->dates_seen++;
        debug_print_current_time (_("date"), pc);
      }
  | day
      {
        pc->days_seen++;
        debug_print_current_time (_("day"), pc);
      }
  | rel
      {
        debug_print_relative_time (_("relative"), pc);
      }
  | number
      {
        debug_print_current_time (_("number"), pc);
      }
  | hybrid
      {
        debug_print_relative_time (_("hybrid"), pc);
      }
  ;

datetime:
    iso_8601_datetime
  ;

iso_8601_datetime:
    iso_8601_date 'T' iso_8601_time
  ;

time:
    tUNUMBER tMERIDIAN
      {
        set_hhmmss (pc, $1.value, 0, 0, 0);
        pc->meridian = $2;
      }
  | tUNUMBER ':' tUNUMBER tMERIDIAN
      {
        set_hhmmss (pc, $1.value, $3.value, 0, 0);
        pc->meridian = $4;
      }
  | tUNUMBER ':' tUNUMBER ':' unsigned_seconds tMERIDIAN
      {
        set_hhmmss (pc, $1.value, $3.value, $5.tv_sec, $5.tv_nsec);
        pc->meridian = $6;
      }
  | iso_8601_time
  ;

iso_8601_time:
    tUNUMBER zone_offset
      {
        set_hhmmss (pc, $1.value, 0, 0, 0);
        pc->meridian = MER24;
      }
  | tUNUMBER ':' tUNUMBER o_zone_offset
      {
        set_hhmmss (pc, $1.value, $3.value, 0, 0);
        pc->meridian = MER24;
      }
  | tUNUMBER ':' tUNUMBER ':' unsigned_seconds o_zone_offset
      {
        set_hhmmss (pc, $1.value, $3.value, $5.tv_sec, $5.tv_nsec);
        pc->meridian = MER24;
      }
  ;

o_zone_offset:
  /* empty */
  | zone_offset
  ;

zone_offset:
    tSNUMBER o_colon_minutes
      {
        pc->zones_seen++;
        pc->time_zone = time_zone_hhmm (pc, $1, $2);
      }
  ;

/* Local zone strings only affect DST setting,
   and only take affect if the current TZ setting is relevant.

   Example 1:
   'EEST' is parsed as tLOCAL_ZONE, as it relates to the effective TZ:
        TZ=Europe/Helsinki date -d '2016-12-30 EEST'

   Example 2:
   'EEST' is parsed as 'zone' (TZ=+03:00):
         TZ=Asia/Tokyo ./src/date --debug -d '2011-06-11 EEST'

   This is implemented by probing the next three calendar quarters
   of the effective timezone and looking for DST changes -
   if found, the timezone name (EEST) is inserted into
   the lexical lookup table with type tLOCAL_ZONE.
   (Search for 'quarter' comment in  'parse_datetime2').
*/
local_zone:
    tLOCAL_ZONE
      {
        pc->local_isdst = $1;
        pc->dsts_seen += (0 < $1);
      }
  | tLOCAL_ZONE tDST
      {
        pc->local_isdst = 1;
        pc->dsts_seen += (0 < $1) + 1;
      }
  ;

/* Note 'T' is a special case, as it is used as the separator in ISO
   8601 date and time of day representation. */
zone:
    tZONE
      { pc->time_zone = $1; }
  | 'T'
      { pc->time_zone = HOUR(7); }
  | tZONE relunit_snumber
      { pc->time_zone = $1;
        apply_relative_time (pc, $2, 1);
        debug_print_relative_time (_("relative"), pc);
      }
  | 'T' relunit_snumber
      { pc->time_zone = HOUR(7);
        apply_relative_time (pc, $2, 1);
        debug_print_relative_time (_("relative"), pc);
      }
  | tZONE tSNUMBER o_colon_minutes
      { pc->time_zone = $1 + time_zone_hhmm (pc, $2, $3); }
  | tDAYZONE
      { pc->time_zone = $1 + 60; }
  | tZONE tDST
      { pc->time_zone = $1 + 60; }
  ;

day:
    tDAY
      {
        pc->day_ordinal = 0;
        pc->day_number = $1;
      }
  | tDAY ','
      {
        pc->day_ordinal = 0;
        pc->day_number = $1;
      }
  | tORDINAL tDAY
      {
        pc->day_ordinal = $1;
        pc->day_number = $2;
        pc->debug_ordinal_day_seen = true;
      }
  | tUNUMBER tDAY
      {
        pc->day_ordinal = $1.value;
        pc->day_number = $2;
        pc->debug_ordinal_day_seen = true;
      }
  ;

date:
    tUNUMBER '/' tUNUMBER
      {
        pc->month = $1.value;
        pc->day = $3.value;
      }
  | tUNUMBER '/' tUNUMBER '/' tUNUMBER
      {
        /* Interpret as YYYY/MM/DD if the first value has 4 or more digits,
           otherwise as MM/DD/YY.
           The goal in recognizing YYYY/MM/DD is solely to support legacy
           machine-generated dates like those in an RCS log listing.  If
           you want portability, use the ISO 8601 format.  */
        if (4 <= $1.digits)
          {
            if (pc->parse_datetime_debug)
              dbg_printf (_("warning: value %ld has %"PRIuMAX" digits. " \
                            "Assuming YYYY/MM/DD\n"), $1.value, $1.digits);

            pc->year = $1;
            pc->month = $3.value;
            pc->day = $5.value;
          }
        else
          {
            if (pc->parse_datetime_debug)
              dbg_printf (_("warning: value %ld has less than 4 digits. "    \
                            "Assuming MM/DD/YY[YY]\n"), $1.value);

            pc->month = $1.value;
            pc->day = $3.value;
            pc->year = $5;
          }
      }
  | tUNUMBER tMONTH tSNUMBER
      {
        /* e.g. 17-JUN-1992.  */
        pc->day = $1.value;
        pc->month = $2;
        pc->year.value = -$3.value;
        pc->year.digits = $3.digits;
      }
  | tMONTH tSNUMBER tSNUMBER
      {
        /* e.g. JUN-17-1992.  */
        pc->month = $1;
        pc->day = -$2.value;
        pc->year.value = -$3.value;
        pc->year.digits = $3.digits;
      }
  | tMONTH tUNUMBER
      {
        pc->month = $1;
        pc->day = $2.value;
      }
  | tMONTH tUNUMBER ',' tUNUMBER
      {
        pc->month = $1;
        pc->day = $2.value;
        pc->year = $4;
      }
  | tUNUMBER tMONTH
      {
        pc->day = $1.value;
        pc->month = $2;
      }
  | tUNUMBER tMONTH tUNUMBER
      {
        pc->day = $1.value;
        pc->month = $2;
        pc->year = $3;
      }
  | iso_8601_date
  ;

iso_8601_date:
    tUNUMBER tSNUMBER tSNUMBER
      {
        /* ISO 8601 format.  YYYY-MM-DD.  */
        pc->year = $1;
        pc->month = -$2.value;
        pc->day = -$3.value;
      }
  ;

rel:
    relunit tAGO
      { apply_relative_time (pc, $1, $2); }
  | relunit
      { apply_relative_time (pc, $1, 1); }
  | dayshift
      { apply_relative_time (pc, $1, 1); }
  ;

relunit:
    tORDINAL tYEAR_UNIT
      { $$ = RELATIVE_TIME_0; $$.year = $1; }
  | tUNUMBER tYEAR_UNIT
      { $$ = RELATIVE_TIME_0; $$.year = $1.value; }
  | tYEAR_UNIT
      { $$ = RELATIVE_TIME_0; $$.year = 1; }
  | tORDINAL tMONTH_UNIT
      { $$ = RELATIVE_TIME_0; $$.month = $1; }
  | tUNUMBER tMONTH_UNIT
      { $$ = RELATIVE_TIME_0; $$.month = $1.value; }
  | tMONTH_UNIT
      { $$ = RELATIVE_TIME_0; $$.month = 1; }
  | tORDINAL tDAY_UNIT
      { $$ = RELATIVE_TIME_0; $$.day = $1 * $2; }
  | tUNUMBER tDAY_UNIT
      { $$ = RELATIVE_TIME_0; $$.day = $1.value * $2; }
  | tDAY_UNIT
      { $$ = RELATIVE_TIME_0; $$.day = $1; }
  | tORDINAL tHOUR_UNIT
      { $$ = RELATIVE_TIME_0; $$.hour = $1; }
  | tUNUMBER tHOUR_UNIT
      { $$ = RELATIVE_TIME_0; $$.hour = $1.value; }
  | tHOUR_UNIT
      { $$ = RELATIVE_TIME_0; $$.hour = 1; }
  | tORDINAL tMINUTE_UNIT
      { $$ = RELATIVE_TIME_0; $$.minutes = $1; }
  | tUNUMBER tMINUTE_UNIT
      { $$ = RELATIVE_TIME_0; $$.minutes = $1.value; }
  | tMINUTE_UNIT
      { $$ = RELATIVE_TIME_0; $$.minutes = 1; }
  | tORDINAL tSEC_UNIT
      { $$ = RELATIVE_TIME_0; $$.seconds = $1; }
  | tUNUMBER tSEC_UNIT
      { $$ = RELATIVE_TIME_0; $$.seconds = $1.value; }
  | tSDECIMAL_NUMBER tSEC_UNIT
      { $$ = RELATIVE_TIME_0; $$.seconds = $1.tv_sec; $$.ns = $1.tv_nsec; }
  | tUDECIMAL_NUMBER tSEC_UNIT
      { $$ = RELATIVE_TIME_0; $$.seconds = $1.tv_sec; $$.ns = $1.tv_nsec; }
  | tSEC_UNIT
      { $$ = RELATIVE_TIME_0; $$.seconds = 1; }
  | relunit_snumber
  ;

relunit_snumber:
    tSNUMBER tYEAR_UNIT
      { $$ = RELATIVE_TIME_0; $$.year = $1.value; }
  | tSNUMBER tMONTH_UNIT
      { $$ = RELATIVE_TIME_0; $$.month = $1.value; }
  | tSNUMBER tDAY_UNIT
      { $$ = RELATIVE_TIME_0; $$.day = $1.value * $2; }
  | tSNUMBER tHOUR_UNIT
      { $$ = RELATIVE_TIME_0; $$.hour = $1.value; }
  | tSNUMBER tMINUTE_UNIT
      { $$ = RELATIVE_TIME_0; $$.minutes = $1.value; }
  | tSNUMBER tSEC_UNIT
      { $$ = RELATIVE_TIME_0; $$.seconds = $1.value; }
  ;

dayshift:
    tDAY_SHIFT
      { $$ = RELATIVE_TIME_0; $$.day = $1; }
  ;

seconds: signed_seconds | unsigned_seconds;

signed_seconds:
    tSDECIMAL_NUMBER
  | tSNUMBER
      { $$.tv_sec = $1.value; $$.tv_nsec = 0; }
  ;

unsigned_seconds:
    tUDECIMAL_NUMBER
  | tUNUMBER
      { $$.tv_sec = $1.value; $$.tv_nsec = 0; }
  ;

number:
    tUNUMBER
      { digits_to_date_time (pc, $1); }
  ;

hybrid:
    tUNUMBER relunit_snumber
      {
        /* Hybrid all-digit and relative offset, so that we accept e.g.,
           "YYYYMMDD +N days" as well as "YYYYMMDD N days".  */
        digits_to_date_time (pc, $1);
        apply_relative_time (pc, $2, 1);
      }
  ;

o_colon_minutes:
    /* empty */
      { $$ = -1; }
  | ':' tUNUMBER
      { $$ = $2.value; }
  ;

%%

static table const meridian_table[] =
{
  { "AM",   tMERIDIAN, MERam },
  { "A.M.", tMERIDIAN, MERam },
  { "PM",   tMERIDIAN, MERpm },
  { "P.M.", tMERIDIAN, MERpm },
  { NULL, 0, 0 }
};

static table const dst_table[] =
{
  { "DST", tDST, 0 }
};

static table const month_and_day_table[] =
{
  { "JANUARY",  tMONTH,  1 },
  { "FEBRUARY", tMONTH,  2 },
  { "MARCH",    tMONTH,  3 },
  { "APRIL",    tMONTH,  4 },
  { "MAY",      tMONTH,  5 },
  { "JUNE",     tMONTH,  6 },
  { "JULY",     tMONTH,  7 },
  { "AUGUST",   tMONTH,  8 },
  { "SEPTEMBER",tMONTH,  9 },
  { "SEPT",     tMONTH,  9 },
  { "OCTOBER",  tMONTH, 10 },
  { "NOVEMBER", tMONTH, 11 },
  { "DECEMBER", tMONTH, 12 },
  { "SUNDAY",   tDAY,    0 },
  { "MONDAY",   tDAY,    1 },
  { "TUESDAY",  tDAY,    2 },
  { "TUES",     tDAY,    2 },
  { "WEDNESDAY",tDAY,    3 },
  { "WEDNES",   tDAY,    3 },
  { "THURSDAY", tDAY,    4 },
  { "THUR",     tDAY,    4 },
  { "THURS",    tDAY,    4 },
  { "FRIDAY",   tDAY,    5 },
  { "SATURDAY", tDAY,    6 },
  { NULL, 0, 0 }
};

static table const time_units_table[] =
{
  { "YEAR",     tYEAR_UNIT,      1 },
  { "MONTH",    tMONTH_UNIT,     1 },
  { "FORTNIGHT",tDAY_UNIT,      14 },
  { "WEEK",     tDAY_UNIT,       7 },
  { "DAY",      tDAY_UNIT,       1 },
  { "HOUR",     tHOUR_UNIT,      1 },
  { "MINUTE",   tMINUTE_UNIT,    1 },
  { "MIN",      tMINUTE_UNIT,    1 },
  { "SECOND",   tSEC_UNIT,       1 },
  { "SEC",      tSEC_UNIT,       1 },
  { NULL, 0, 0 }
};

/* Assorted relative-time words. */
static table const relative_time_table[] =
{
  { "TOMORROW", tDAY_SHIFT,      1 },
  { "YESTERDAY",tDAY_SHIFT,     -1 },
  { "TODAY",    tDAY_SHIFT,      0 },
  { "NOW",      tDAY_SHIFT,      0 },
  { "LAST",     tORDINAL,       -1 },
  { "THIS",     tORDINAL,        0 },
  { "NEXT",     tORDINAL,        1 },
  { "FIRST",    tORDINAL,        1 },
/*{ "SECOND",   tORDINAL,        2 }, */
  { "THIRD",    tORDINAL,        3 },
  { "FOURTH",   tORDINAL,        4 },
  { "FIFTH",    tORDINAL,        5 },
  { "SIXTH",    tORDINAL,        6 },
  { "SEVENTH",  tORDINAL,        7 },
  { "EIGHTH",   tORDINAL,        8 },
  { "NINTH",    tORDINAL,        9 },
  { "TENTH",    tORDINAL,       10 },
  { "ELEVENTH", tORDINAL,       11 },
  { "TWELFTH",  tORDINAL,       12 },
  { "AGO",      tAGO,           -1 },
  { "HENCE",    tAGO,            1 },
  { NULL, 0, 0 }
};

/* The universal time zone table.  These labels can be used even for
   timestamps that would not otherwise be valid, e.g., GMT timestamps
   oin London during summer.  */
static table const universal_time_zone_table[] =
{
  { "GMT",      tZONE,     HOUR ( 0) }, /* Greenwich Mean */
  { "UT",       tZONE,     HOUR ( 0) }, /* Universal (Coordinated) */
  { "UTC",      tZONE,     HOUR ( 0) },
  { NULL, 0, 0 }
};

/* The time zone table.  This table is necessarily incomplete, as time
   zone abbreviations are ambiguous; e.g. Australians interpret "EST"
   as Eastern time in Australia, not as US Eastern Standard Time.
   You cannot rely on parse_datetime to handle arbitrary time zone
   abbreviations; use numeric abbreviations like "-0500" instead.  */
static table const time_zone_table[] =
{
  { "WET",      tZONE,     HOUR ( 0) }, /* Western European */
  { "WEST",     tDAYZONE,  HOUR ( 0) }, /* Western European Summer */
  { "BST",      tDAYZONE,  HOUR ( 0) }, /* British Summer */
  { "ART",      tZONE,    -HOUR ( 3) }, /* Argentina */
  { "BRT",      tZONE,    -HOUR ( 3) }, /* Brazil */
  { "BRST",     tDAYZONE, -HOUR ( 3) }, /* Brazil Summer */
  { "NST",      tZONE,   -(HOUR ( 3) + 30) },   /* Newfoundland Standard */
  { "NDT",      tDAYZONE,-(HOUR ( 3) + 30) },   /* Newfoundland Daylight */
  { "AST",      tZONE,    -HOUR ( 4) }, /* Atlantic Standard */
  { "ADT",      tDAYZONE, -HOUR ( 4) }, /* Atlantic Daylight */
  { "CLT",      tZONE,    -HOUR ( 4) }, /* Chile */
  { "CLST",     tDAYZONE, -HOUR ( 4) }, /* Chile Summer */
  { "EST",      tZONE,    -HOUR ( 5) }, /* Eastern Standard */
  { "EDT",      tDAYZONE, -HOUR ( 5) }, /* Eastern Daylight */
  { "CST",      tZONE,    -HOUR ( 6) }, /* Central Standard */
  { "CDT",      tDAYZONE, -HOUR ( 6) }, /* Central Daylight */
  { "MST",      tZONE,    -HOUR ( 7) }, /* Mountain Standard */
  { "MDT",      tDAYZONE, -HOUR ( 7) }, /* Mountain Daylight */
  { "PST",      tZONE,    -HOUR ( 8) }, /* Pacific Standard */
  { "PDT",      tDAYZONE, -HOUR ( 8) }, /* Pacific Daylight */
  { "AKST",     tZONE,    -HOUR ( 9) }, /* Alaska Standard */
  { "AKDT",     tDAYZONE, -HOUR ( 9) }, /* Alaska Daylight */
  { "HST",      tZONE,    -HOUR (10) }, /* Hawaii Standard */
  { "HAST",     tZONE,    -HOUR (10) }, /* Hawaii-Aleutian Standard */
  { "HADT",     tDAYZONE, -HOUR (10) }, /* Hawaii-Aleutian Daylight */
  { "SST",      tZONE,    -HOUR (12) }, /* Samoa Standard */
  { "WAT",      tZONE,     HOUR ( 1) }, /* West Africa */
  { "CET",      tZONE,     HOUR ( 1) }, /* Central European */
  { "CEST",     tDAYZONE,  HOUR ( 1) }, /* Central European Summer */
  { "MET",      tZONE,     HOUR ( 1) }, /* Middle European */
  { "MEZ",      tZONE,     HOUR ( 1) }, /* Middle European */
  { "MEST",     tDAYZONE,  HOUR ( 1) }, /* Middle European Summer */
  { "MESZ",     tDAYZONE,  HOUR ( 1) }, /* Middle European Summer */
  { "EET",      tZONE,     HOUR ( 2) }, /* Eastern European */
  { "EEST",     tDAYZONE,  HOUR ( 2) }, /* Eastern European Summer */
  { "CAT",      tZONE,     HOUR ( 2) }, /* Central Africa */
  { "SAST",     tZONE,     HOUR ( 2) }, /* South Africa Standard */
  { "EAT",      tZONE,     HOUR ( 3) }, /* East Africa */
  { "MSK",      tZONE,     HOUR ( 3) }, /* Moscow */
  { "MSD",      tDAYZONE,  HOUR ( 3) }, /* Moscow Daylight */
  { "IST",      tZONE,    (HOUR ( 5) + 30) },   /* India Standard */
  { "SGT",      tZONE,     HOUR ( 8) }, /* Singapore */
  { "KST",      tZONE,     HOUR ( 9) }, /* Korea Standard */
  { "JST",      tZONE,     HOUR ( 9) }, /* Japan Standard */
  { "GST",      tZONE,     HOUR (10) }, /* Guam Standard */
  { "NZST",     tZONE,     HOUR (12) }, /* New Zealand Standard */
  { "NZDT",     tDAYZONE,  HOUR (12) }, /* New Zealand Daylight */
  { NULL, 0, 0 }
};

/* Military time zone table.

   Note 'T' is a special case, as it is used as the separator in ISO
   8601 date and time of day representation. */
static table const military_table[] =
{
  { "A", tZONE, -HOUR ( 1) },
  { "B", tZONE, -HOUR ( 2) },
  { "C", tZONE, -HOUR ( 3) },
  { "D", tZONE, -HOUR ( 4) },
  { "E", tZONE, -HOUR ( 5) },
  { "F", tZONE, -HOUR ( 6) },
  { "G", tZONE, -HOUR ( 7) },
  { "H", tZONE, -HOUR ( 8) },
  { "I", tZONE, -HOUR ( 9) },
  { "K", tZONE, -HOUR (10) },
  { "L", tZONE, -HOUR (11) },
  { "M", tZONE, -HOUR (12) },
  { "N", tZONE,  HOUR ( 1) },
  { "O", tZONE,  HOUR ( 2) },
  { "P", tZONE,  HOUR ( 3) },
  { "Q", tZONE,  HOUR ( 4) },
  { "R", tZONE,  HOUR ( 5) },
  { "S", tZONE,  HOUR ( 6) },
  { "T", 'T',    0 },
  { "U", tZONE,  HOUR ( 8) },
  { "V", tZONE,  HOUR ( 9) },
  { "W", tZONE,  HOUR (10) },
  { "X", tZONE,  HOUR (11) },
  { "Y", tZONE,  HOUR (12) },
  { "Z", tZONE,  HOUR ( 0) },
  { NULL, 0, 0 }
};



/* Convert a time zone expressed as HH:MM into an integer count of
   minutes.  If MM is negative, then S is of the form HHMM and needs
   to be picked apart; otherwise, S is of the form HH.  As specified in
   http://www.opengroup.org/susv3xbd/xbd_chap08.html#tag_08_03, allow
   only valid TZ range, and consider first two digits as hours, if no
   minutes specified.  */

static long int
time_zone_hhmm (parser_control *pc, textint s, long int mm)
{
  long int n_minutes;

  /* If the length of S is 1 or 2 and no minutes are specified,
     interpret it as a number of hours.  */
  if (s.digits <= 2 && mm < 0)
    s.value *= 100;

  if (mm < 0)
    n_minutes = (s.value / 100) * 60 + s.value % 100;
  else
    n_minutes = s.value * 60 + (s.negative ? -mm : mm);

  /* If the absolute number of minutes is larger than 24 hours,
     arrange to reject it by incrementing pc->zones_seen.  Thus,
     we allow only values in the range UTC-24:00 to UTC+24:00.  */
  if (24 * 60 < abs (n_minutes))
    pc->zones_seen++;

  return n_minutes;
}

static int
to_hour (long int hours, int meridian)
{
  switch (meridian)
    {
    default: /* Pacify GCC.  */
    case MER24:
      return 0 <= hours && hours < 24 ? hours : -1;
    case MERam:
      return 0 < hours && hours < 12 ? hours : hours == 12 ? 0 : -1;
    case MERpm:
      return 0 < hours && hours < 12 ? hours + 12 : hours == 12 ? 12 : -1;
    }
}

static long int
to_year (textint textyear, bool debug)
{
  long int year = textyear.value;

  if (year < 0)
    year = -year;

  /* XPG4 suggests that years 00-68 map to 2000-2068, and
     years 69-99 map to 1969-1999.  */
  else if (textyear.digits == 2)
    {
      year += year < 69 ? 2000 : 1900;
      if (debug)
        dbg_printf (_("warning: adjusting year value %ld to %ld\n"),
                    textyear.value, year);
    }

  return year;
}

static table const * _GL_ATTRIBUTE_PURE
lookup_zone (parser_control const *pc, char const *name)
{
  table const *tp;

  for (tp = universal_time_zone_table; tp->name; tp++)
    if (strcmp (name, tp->name) == 0)
      return tp;

  /* Try local zone abbreviations before those in time_zone_table, as
     the local ones are more likely to be right.  */
  for (tp = pc->local_time_zone_table; tp->name; tp++)
    if (strcmp (name, tp->name) == 0)
      return tp;

  for (tp = time_zone_table; tp->name; tp++)
    if (strcmp (name, tp->name) == 0)
      return tp;

  return NULL;
}

#if ! HAVE_TM_GMTOFF
/* Yield the difference between *A and *B,
   measured in seconds, ignoring leap seconds.
   The body of this function is taken directly from the GNU C Library;
   see src/strftime.c.  */
static long int
tm_diff (struct tm const *a, struct tm const *b)
{
  /* Compute intervening leap days correctly even if year is negative.
     Take care to avoid int overflow in leap day calculations.  */
  int a4 = SHR (a->tm_year, 2) + SHR (TM_YEAR_BASE, 2) - ! (a->tm_year & 3);
  int b4 = SHR (b->tm_year, 2) + SHR (TM_YEAR_BASE, 2) - ! (b->tm_year & 3);
  int a100 = a4 / 25 - (a4 % 25 < 0);
  int b100 = b4 / 25 - (b4 % 25 < 0);
  int a400 = SHR (a100, 2);
  int b400 = SHR (b100, 2);
  int intervening_leap_days = (a4 - b4) - (a100 - b100) + (a400 - b400);
  long int ayear = a->tm_year;
  long int years = ayear - b->tm_year;
  long int days = (365 * years + intervening_leap_days
                   + (a->tm_yday - b->tm_yday));
  return (60 * (60 * (24 * days + (a->tm_hour - b->tm_hour))
                + (a->tm_min - b->tm_min))
          + (a->tm_sec - b->tm_sec));
}
#endif /* ! HAVE_TM_GMTOFF */

static table const *
lookup_word (parser_control const *pc, char *word)
{
  char *p;
  char *q;
  size_t wordlen;
  table const *tp;
  bool period_found;
  bool abbrev;

  /* Make it uppercase.  */
  for (p = word; *p; p++)
    {
      unsigned char ch = *p;
      *p = c_toupper (ch);
    }

  for (tp = meridian_table; tp->name; tp++)
    if (strcmp (word, tp->name) == 0)
      return tp;

  /* See if we have an abbreviation for a month. */
  wordlen = strlen (word);
  abbrev = wordlen == 3 || (wordlen == 4 && word[3] == '.');

  for (tp = month_and_day_table; tp->name; tp++)
    if ((abbrev ? strncmp (word, tp->name, 3) : strcmp (word, tp->name)) == 0)
      return tp;

  if ((tp = lookup_zone (pc, word)))
    return tp;

  if (strcmp (word, dst_table[0].name) == 0)
    return dst_table;

  for (tp = time_units_table; tp->name; tp++)
    if (strcmp (word, tp->name) == 0)
      return tp;

  /* Strip off any plural and try the units table again. */
  if (word[wordlen - 1] == 'S')
    {
      word[wordlen - 1] = '\0';
      for (tp = time_units_table; tp->name; tp++)
        if (strcmp (word, tp->name) == 0)
          return tp;
      word[wordlen - 1] = 'S';  /* For "this" in relative_time_table.  */
    }

  for (tp = relative_time_table; tp->name; tp++)
    if (strcmp (word, tp->name) == 0)
      return tp;

  /* Military time zones. */
  if (wordlen == 1)
    for (tp = military_table; tp->name; tp++)
      if (word[0] == tp->name[0])
        return tp;

  /* Drop out any periods and try the time zone table again. */
  for (period_found = false, p = q = word; (*p = *q); q++)
    if (*q == '.')
      period_found = true;
    else
      p++;
  if (period_found && (tp = lookup_zone (pc, word)))
    return tp;

  return NULL;
}

static int
yylex (union YYSTYPE *lvalp, parser_control *pc)
{
  unsigned char c;
  size_t count;

  for (;;)
    {
      while (c = *pc->input, c_isspace (c))
        pc->input++;

      if (ISDIGIT (c) || c == '-' || c == '+')
        {
          char const *p;
          int sign;
          unsigned long int value;
          if (c == '-' || c == '+')
            {
              sign = c == '-' ? -1 : 1;
              while (c = *++pc->input, c_isspace (c))
                continue;
              if (! ISDIGIT (c))
                /* skip the '-' sign */
                continue;
            }
          else
            sign = 0;
          p = pc->input;
          for (value = 0; ; value *= 10)
            {
              unsigned long int value1 = value + (c - '0');
              if (value1 < value)
                return '?';
              value = value1;
              c = *++p;
              if (! ISDIGIT (c))
                break;
              if (ULONG_MAX / 10 < value)
                return '?';
            }
          if ((c == '.' || c == ',') && ISDIGIT (p[1]))
            {
              time_t s;
              int ns;
              int digits;
              unsigned long int value1;

              /* Check for overflow when converting value to time_t.  */
              if (sign < 0)
                {
                  s = - value;
                  if (0 < s)
                    return '?';
                  value1 = -s;
                }
              else
                {
                  s = value;
                  if (s < 0)
                    return '?';
                  value1 = s;
                }
              if (value != value1)
                return '?';

              /* Accumulate fraction, to ns precision.  */
              p++;
              ns = *p++ - '0';
              for (digits = 2; digits <= LOG10_BILLION; digits++)
                {
                  ns *= 10;
                  if (ISDIGIT (*p))
                    ns += *p++ - '0';
                }

              /* Skip excess digits, truncating toward -Infinity.  */
              if (sign < 0)
                for (; ISDIGIT (*p); p++)
                  if (*p != '0')
                    {
                      ns++;
                      break;
                    }
              while (ISDIGIT (*p))
                p++;

              /* Adjust to the timespec convention, which is that
                 tv_nsec is always a positive offset even if tv_sec is
                 negative.  */
              if (sign < 0 && ns)
                {
                  s--;
                  if (! (s < 0))
                    return '?';
                  ns = BILLION - ns;
                }

              lvalp->timespec.tv_sec = s;
              lvalp->timespec.tv_nsec = ns;
              pc->input = p;
              return sign ? tSDECIMAL_NUMBER : tUDECIMAL_NUMBER;
            }
          else
            {
              lvalp->textintval.negative = sign < 0;
              if (sign < 0)
                {
                  lvalp->textintval.value = - value;
                  if (0 < lvalp->textintval.value)
                    return '?';
                }
              else
                {
                  lvalp->textintval.value = value;
                  if (lvalp->textintval.value < 0)
                    return '?';
                }
              lvalp->textintval.digits = p - pc->input;
              pc->input = p;
              return sign ? tSNUMBER : tUNUMBER;
            }
        }

      if (c_isalpha (c))
        {
          char buff[20];
          char *p = buff;
          table const *tp;

          do
            {
              if (p < buff + sizeof buff - 1)
                *p++ = c;
              c = *++pc->input;
            }
          while (c_isalpha (c) || c == '.');

          *p = '\0';
          tp = lookup_word (pc, buff);
          if (! tp)
            {
              if (pc->parse_datetime_debug)
                dbg_printf (_("error: unknown word '%s'\n"), buff);
              return '?';
            }
          lvalp->intval = tp->value;
          return tp->type;
        }

      if (c != '(')
        return to_uchar (*pc->input++);

      count = 0;
      do
        {
          c = *pc->input++;
          if (c == '\0')
            return c;
          if (c == '(')
            count++;
          else if (c == ')')
            count--;
        }
      while (count != 0);
    }
}

/* Do nothing if the parser reports an error.  */
static int
yyerror (parser_control const *pc _GL_UNUSED,
         char const *s _GL_UNUSED)
{
  return 0;
}

/* In timezone TZ, if *TM0 is the old and *TM1 is the new value of a
   struct tm after passing it to mktime_z, return true if it's OK that
   mktime_z returned T.  It's not OK if *TM0 has out-of-range
   members.  */

static bool
mktime_ok (timezone_t tz, struct tm const *tm0, struct tm const *tm1, time_t t)
{
  struct tm ltm;
  if (t == (time_t) -1)
    {
      /* Guard against falsely reporting an error when parsing a
         timestamp that happens to equal (time_t) -1, on a host that
         supports such a timestamp.  */
      tm1 = localtime_rz (tz, &t, &ltm);
      if (!tm1)
        return false;
    }

  return ! ((tm0->tm_sec ^ tm1->tm_sec)
            | (tm0->tm_min ^ tm1->tm_min)
            | (tm0->tm_hour ^ tm1->tm_hour)
            | (tm0->tm_mday ^ tm1->tm_mday)
            | (tm0->tm_mon ^ tm1->tm_mon)
            | (tm0->tm_year ^ tm1->tm_year));
}

/* A reasonable upper bound for the size of ordinary TZ strings.
   Use heap allocation if TZ's length exceeds this.  */
enum { TZBUFSIZE = 100 };

/* A reasonable upper bound for the buffer used in debug print outs.
   see days_to_name(), debug_strftime() and debug_mktime_not_ok() */
enum { DBGBUFSIZE = 100 };

/* debugging: format a 'struct tm' into a buffer, taking the parser's
   timezone information into account (if pc!=NULL). */
static const char*
debug_strfdatetime (const struct tm *tm, const parser_control *pc,
                    char* /*output*/ buf, size_t n)
{
  /* TODO:
     1. find an optimal way to print date string in a clear and unambiguous
        format. Currently, always add '(Y-M-D)' prefix.
        Consider '2016y01m10d'  or 'year(2016) month(01) day(10)'.

        If the user needs debug printing, it means he/she already having
        issues with the parsing - better to avoid formats that could
        be mis-interpreted (e.g. just YYYY-MM-DD).

     2. Can strftime be used instead?
        depends if it is portable and can print invalid dates on all systems.

     3. Print timezone information ?

     4. Print DST information ?

     5. Print nanosecond information ?

     NOTE:
     Printed date/time values might not be valid, e.g. '2016-02-31'
     or '2016-19-2016' .  These are the values as parsed from the user
     string, before validation.
  */
  int m = nstrftime (buf, n, "(Y-M-D) %Y-%m-%d %H:%M:%S", tm, 0, 0);

  /* if parser_control information was provided (for timezone),
     and there's enough space in the buffer - add timezone info */
  if (pc != NULL && ((n-m)>0))
    {
      long int tz = (pc->zones_seen)
                    ? pc->time_zone
                    : pc->debug_default_input_timezone;

      /* Account for DST if tLOCAL_ZONE was seen */
      if (pc->local_zones_seen && !pc->zones_seen && pc->local_isdst==1)
        tz += 60;

      snprintf (&buf[m],n-m," TZ=%+03d:%02d", (int)(tz/60), abs ((int)tz)%60);
    }
  return buf;
}

static const char*
debug_strfdate (const struct tm *tm, char* /*output*/ buf, size_t n)
{
  snprintf (buf,n,"(Y-M-D) %04d-%02d-%02d",
            tm->tm_year+1900, tm->tm_mon+1, tm->tm_mday);
  return buf;
}

static const char*
debug_strftime (const struct tm *tm, char* /*output*/ buf, size_t n)
{
  snprintf (buf,n,"%02d:%02d:%02d", tm->tm_hour, tm->tm_min, tm->tm_sec);
  return buf;
}

/* If 'mktime_ok()' failed, display the failed time values,
   and provide possible hints. Example output:

    date: error: invalid date/time value:
    date:     user provided time: '(Y-M-D) 2006-04-02 02:45:00'
    date:        normalized time: '(Y-M-D) 2006-04-02 03:45:00'
    date:                                             __
    date:      possible reasons:
    date:        non-existing due to daylight-saving time;
    date:        numeric values overflow;
    date:        missing timezone;
 */
static void
debug_mktime_not_ok (struct tm const *tm0, struct tm const *tm1,
                     const parser_control *pc,  bool time_zone_seen)
{
  /* TODO: handle t==-1 (as in 'mktime_ok') */
  char tmp[DBGBUFSIZE];
  int i;
  const bool eq_sec   = (tm0->tm_sec  == tm1->tm_sec);
  const bool eq_min   = (tm0->tm_min  == tm1->tm_min);
  const bool eq_hour  = (tm0->tm_hour == tm1->tm_hour);
  const bool eq_mday  = (tm0->tm_mday == tm1->tm_mday);
  const bool eq_month = (tm0->tm_mon  == tm1->tm_mon);
  const bool eq_year  = (tm0->tm_year == tm1->tm_year);

  const bool dst_shift = eq_sec && eq_min && !eq_hour
                         && eq_mday && eq_month && eq_year;

  if (!pc->parse_datetime_debug)
    return;

  dbg_printf (_("error: invalid date/time value:\n"));
  dbg_printf (_("    user provided time: '%s'\n"),
              debug_strfdatetime (tm0, pc, tmp, sizeof (tmp)));
  dbg_printf (_("       normalized time: '%s'\n"),
              debug_strfdatetime (tm1, pc, tmp, sizeof (tmp)));
  /* NOTEs: the format must be aligned with debug_strfdatetime() and the two
            DEBUG statements above. this string is not translated. */
  i = snprintf (tmp, sizeof(tmp),
                "                                 %4s %2s %2s %2s %2s %2s",
                eq_year?"":"----", eq_month?"":"--", eq_mday?"":"--",
                eq_hour?"":"--", eq_min?"":"--", eq_sec?"":"--");
  /* Trim trailing whitespace */
  if ((i>0) && (i<sizeof(tmp)))
    {
      while ((i>0) && (tmp[i-1]==' '))
        --i;
      tmp[i] = '\0';
    }
  dbg_printf ("%s\n", tmp);

  dbg_printf (_("     possible reasons:\n"));
  if (dst_shift)
    dbg_printf (_("       non-existing due to daylight-saving time;\n"));
  if (!eq_mday && !eq_month)
    dbg_printf (_("       invalid day/month combination;\n"));
  dbg_printf (_("       numeric values overflow;\n"));
  dbg_printf ("       %s\n",time_zone_seen?_("incorrect timezone")
                                          :_("missing timezone"));
}


/* Returns the effective local timezone, in minutes. */
static long int
get_effective_timezone (timezone_t tz)
{
  time_t z = 0;
  struct tm tm;
  if (! localtime_rz (tz, &z, &tm))
    return 0;
  return timegm (&tm) / 60;
}

/* The original interface: run with debug=false and the default timezone.   */
bool
parse_datetime (struct timespec *result, char const *p,
                struct timespec const *now)
{
  char const *tzstring = getenv ("TZ");
  timezone_t tz = tzalloc (tzstring);
  if (!tz)
    return false;
  bool ok = parse_datetime2 (result, p, now, 0, tz, tzstring);
  tzfree (tz);
  return ok;
}

/* Parse a date/time string, storing the resulting time value into *RESULT.
   The string itself is pointed to by P.  Return true if successful.
   P can be an incomplete or relative time specification; if so, use
   *NOW as the basis for the returned time.  Default to timezone
   TZDEFAULT, which corresponds to tzalloc (TZSTRING).  */
bool
parse_datetime2 (struct timespec *result, char const *p,
                 struct timespec const *now, unsigned int flags,
                 timezone_t tzdefault, char const *tzstring)
{
  time_t Start;
  long int Start_ns;
  struct tm tmp;
  struct tm tm;
  struct tm tm0;
  parser_control pc;
  struct timespec gettime_buffer;
  unsigned char c;
  timezone_t tz = tzdefault;
  bool ok = true;
  char dbg_ord[DBGBUFSIZE];
  char dbg_tm[DBGBUFSIZE];
  char const *input_sentinel = p + strlen (p);
  char *tz1alloc = NULL;
  char tz1buf[TZBUFSIZE];

  if (! now)
    {
      gettime (&gettime_buffer);
      now = &gettime_buffer;
    }

  Start = now->tv_sec;
  Start_ns = now->tv_nsec;

  while (c = *p, c_isspace (c))
    p++;

  if (strncmp (p, "TZ=\"", 4) == 0)
    {
      char const *tzbase = p + 4;
      size_t tzsize = 1;
      char const *s;

      for (s = tzbase; *s; s++, tzsize++)
        if (*s == '\\')
          {
            s++;
            if (! (*s == '\\' || *s == '"'))
              break;
          }
        else if (*s == '"')
          {
            timezone_t tz1;
            char *tz1string = tz1buf;
            char *z;
            if (TZBUFSIZE < tzsize)
              {
                tz1alloc = malloc (tzsize);
                if (!tz1alloc)
                  goto fail;
                tz1string = tz1alloc;
              }
            z = tz1string;
            for (s = tzbase; *s != '"'; s++)
              *z++ = *(s += *s == '\\');
            *z = '\0';
            tz1 = tzalloc (tz1string);
            if (!tz1)
              goto fail;
            tz = tz1;
            tzstring = tz1string;

            p = s + 1;
            while (c = *p, c_isspace (c))
              p++;

            break;
          }
    }

  if (! localtime_rz (tz, &now->tv_sec, &tmp))
    return false;

  /* As documented, be careful to treat the empty string just like
     a date string of "0".  Without this, an empty string would be
     declared invalid when parsed during a DST transition.  */
  if (*p == '\0')
    p = "0";

  pc.input = p;
  pc.year.value = tmp.tm_year;
  pc.year.value += TM_YEAR_BASE;
  pc.year.digits = 0;
  pc.month = tmp.tm_mon + 1;
  pc.day = tmp.tm_mday;
  pc.hour = tmp.tm_hour;
  pc.minutes = tmp.tm_min;
  pc.seconds.tv_sec = tmp.tm_sec;
  pc.seconds.tv_nsec = Start_ns;
  tm.tm_isdst = tmp.tm_isdst;

  pc.meridian = MER24;
  pc.rel = RELATIVE_TIME_0;
  pc.timespec_seen = false;
  pc.rels_seen = false;
  pc.dates_seen = 0;
  pc.days_seen = 0;
  pc.times_seen = 0;
  pc.local_zones_seen = 0;
  pc.dsts_seen = 0;
  pc.zones_seen = 0;
  pc.year_seen = 0;
  pc.parse_datetime_debug = (flags & PARSE_DATETIME_DEBUG)!=0;
  pc.debug_dates_seen = 0;
  pc.debug_days_seen = 0;
  pc.debug_times_seen = 0;
  pc.debug_local_zones_seen = 0;
  pc.debug_dsts_seen = 0;
  pc.debug_zones_seen = 0;
  pc.debug_year_seen = 0;
  pc.debug_ordinal_day_seen = false;
  pc.debug_default_input_timezone = 0;

#if HAVE_STRUCT_TM_TM_ZONE
  pc.local_time_zone_table[0].name = tmp.tm_zone;
  pc.local_time_zone_table[0].type = tLOCAL_ZONE;
  pc.local_time_zone_table[0].value = tmp.tm_isdst;
  pc.local_time_zone_table[1].name = NULL;

  /* Probe the names used in the next three calendar quarters, looking
     for a tm_isdst different from the one we already have.  */
  {
    int quarter;
    for (quarter = 1; quarter <= 3; quarter++)
      {
        time_t probe = Start + quarter * (90 * 24 * 60 * 60);
        struct tm probe_tm;
        if (localtime_rz (tz, &probe, &probe_tm) && probe_tm.tm_zone
            && probe_tm.tm_isdst != pc.local_time_zone_table[0].value)
          {
              {
                pc.local_time_zone_table[1].name = probe_tm.tm_zone;
                pc.local_time_zone_table[1].type = tLOCAL_ZONE;
                pc.local_time_zone_table[1].value = probe_tm.tm_isdst;
                pc.local_time_zone_table[2].name = NULL;
              }
            break;
          }
      }
  }
#else
#if HAVE_TZNAME
  {
# if !HAVE_DECL_TZNAME
    extern char *tzname[];
# endif
    int i;
    for (i = 0; i < 2; i++)
      {
        pc.local_time_zone_table[i].name = tzname[i];
        pc.local_time_zone_table[i].type = tLOCAL_ZONE;
        pc.local_time_zone_table[i].value = i;
      }
    pc.local_time_zone_table[i].name = NULL;
  }
#else
  pc.local_time_zone_table[0].name = NULL;
#endif
#endif

  if (pc.local_time_zone_table[0].name && pc.local_time_zone_table[1].name
      && ! strcmp (pc.local_time_zone_table[0].name,
                   pc.local_time_zone_table[1].name))
    {
      /* This locale uses the same abbreviation for standard and
         daylight times.  So if we see that abbreviation, we don't
         know whether it's daylight time.  */
      pc.local_time_zone_table[0].value = -1;
      pc.local_time_zone_table[1].name = NULL;
    }

  pc.debug_default_input_timezone = get_effective_timezone (tz);

  if (yyparse (&pc) != 0)
    {
      if (pc.parse_datetime_debug)
        {
          if (input_sentinel <= pc.input)
            dbg_printf (_("error: parsing failed\n"), pc.input);
          else
            {
              dbg_printf (_("error: parsing failed, stopped at '%s'\n"),
                          pc.input);
            }
         }
      goto fail;
    }

  /* determine effective timezone source */
  if (pc.parse_datetime_debug)
    {
      long int time_zone = pc.debug_default_input_timezone;

      if (pc.timespec_seen)
        {
          time_zone = 0;
          strncpy (dbg_tm, _("'@timespec' - always UTC0"), sizeof (dbg_tm)-1);
        }
      else if (pc.zones_seen)
        {
          time_zone = pc.time_zone;
          strncpy (dbg_tm, _("parsed date/time string"), sizeof (dbg_tm)-1);
        }
      else if (tzstring)
        {
          if (tz != tzdefault)
            {
              snprintf (dbg_tm, sizeof(dbg_tm), _("TZ=\"%s\" in date string"),
                        tzstring);
            }
          else if (STREQ (tzstring, "UTC0"))
            {
              /* Special case: using 'date -u' simply set TZ=UTC0 */
              strncpy (dbg_tm, _("TZ=UTC0 environment value or -u"),
                       sizeof (dbg_tm)-1);
            }
          else
            {
              snprintf (dbg_tm, sizeof(dbg_tm),
                        _("TZ=\"%s\" environment value"), tzstring);
            }
        }
      else
        {
          strncpy (dbg_tm, _("system default"), sizeof (dbg_tm)-1);
        }

      /* Ensure it's NUL terminated after strncpy */
      dbg_tm[sizeof (dbg_tm)-1] = '\0';

      /* Account for DST changes if tLOCAL_ZONE was seen.
         local timezone only changes DST and is relative to the
         default timezone.*/
      if (pc.local_zones_seen && !pc.zones_seen && pc.local_isdst==1)
        {
          time_zone += 60;
          strncat (dbg_tm, ", dst",
                   sizeof (dbg_tm) - strlen (dbg_tm) - 1);
        }

      if (pc.parse_datetime_debug)
        dbg_printf (_("input timezone: %+03d:%02d (set from %s)\n"),
                    (int) (time_zone / 60), abs ((int) (time_zone % 60)),
                    dbg_tm);

    }

  if (pc.timespec_seen)
    *result = pc.seconds;
  else
    {
      if (1 < (pc.times_seen | pc.dates_seen | pc.days_seen | pc.dsts_seen
               | (pc.local_zones_seen + pc.zones_seen)))
        {
          if (pc.parse_datetime_debug)
            {
              if (pc.times_seen > 1)
                dbg_printf ("error: seen multiple time parts\n");
              if (pc.dates_seen > 1)
                dbg_printf ("error: seen multiple date parts\n");
              if (pc.days_seen > 1)
                dbg_printf ("error: seen multiple days parts\n");
              if (pc.dsts_seen > 1)
                dbg_printf ("error: seen multiple daylight-saving parts\n");
              if ( (pc.local_zones_seen + pc.zones_seen) > 1)
                dbg_printf ("error: seen multiple time-zone parts\n");
            }
          goto fail;
        }

      tm.tm_year = to_year (pc.year, pc.parse_datetime_debug) - TM_YEAR_BASE;
      tm.tm_mon = pc.month - 1;
      tm.tm_mday = pc.day;
      if (pc.times_seen || (pc.rels_seen && ! pc.dates_seen && ! pc.days_seen))
        {
          tm.tm_hour = to_hour (pc.hour, pc.meridian);
          if (tm.tm_hour < 0)
            {
              const char* mrd = (pc.meridian==MERam)?"am":
                                  (pc.meridian==MERpm)?"pm":"";
              if (pc.parse_datetime_debug)
                dbg_printf (_("error: invalid hour %ld%s\n"), pc.hour, mrd);

              goto fail;
            }
          tm.tm_min = pc.minutes;
          tm.tm_sec = pc.seconds.tv_sec;
          if (pc.parse_datetime_debug)
            dbg_printf (_("using %s time as starting value: '%s'\n"),
                        (pc.times_seen)?_("specified"):_("current"),
                        debug_strftime (&tm,dbg_tm,sizeof (dbg_tm)));
        }
      else
        {
          tm.tm_hour = tm.tm_min = tm.tm_sec = 0;
          pc.seconds.tv_nsec = 0;
          if (pc.parse_datetime_debug)
            dbg_printf ("warning: using midnight as starting time: 00:00:00\n");
        }

      /* Let mktime deduce tm_isdst if we have an absolute timestamp.  */
      if (pc.dates_seen | pc.days_seen | pc.times_seen)
        tm.tm_isdst = -1;

      /* But if the input explicitly specifies local time with or without
         DST, give mktime that information.  */
      if (pc.local_zones_seen)
        tm.tm_isdst = pc.local_isdst;

      tm0 = tm;

      Start = mktime_z (tz, &tm);

      if (! mktime_ok (tz, &tm0, &tm, Start))
        {
          if (! pc.zones_seen)
            {
              debug_mktime_not_ok (&tm0, &tm, &pc, pc.zones_seen);

              goto fail;
            }
          else
            {
              /* Guard against falsely reporting errors near the time_t
                 boundaries when parsing times in other time zones.  For
                 example, suppose the input string "1969-12-31 23:00:00 -0100",
                 the current time zone is 8 hours ahead of UTC, and the min
                 time_t value is 1970-01-01 00:00:00 UTC.  Then the min
                 localtime value is 1970-01-01 08:00:00, and mktime will
                 therefore fail on 1969-12-31 23:00:00.  To work around the
                 problem, set the time zone to 1 hour behind UTC temporarily
                 by setting TZ="XXX1:00" and try mktime again.  */

              long int time_zone = pc.time_zone;
              long int abs_time_zone = time_zone < 0 ? - time_zone : time_zone;
              long int abs_time_zone_hour = abs_time_zone / 60;
              int abs_time_zone_min = abs_time_zone % 60;
              char tz2buf[sizeof "XXX+0:00" + TYPE_WIDTH (pc.time_zone) / 3];
              timezone_t tz2;
              sprintf (tz2buf, "XXX%s%ld:%02d", &"-"[time_zone < 0],
                       abs_time_zone_hour, abs_time_zone_min);
              tz2 = tzalloc (tz2buf);
              if (!tz2)
                {
                  if (pc.parse_datetime_debug)
                    dbg_printf (_("error: tzalloc (\"%s\") failed\n"), tz2buf);

                  goto fail;
                }
              tm = tm0;
              Start = mktime_z (tz2, &tm);
              ok = mktime_ok (tz2, &tm0, &tm, Start);
              tzfree (tz2);
              if (! ok)
                {
                  debug_mktime_not_ok (&tm0, &tm, &pc, pc.zones_seen);

                  goto done;
                }
            }
        }

      if (pc.days_seen && ! pc.dates_seen)
        {
          tm.tm_mday += ((pc.day_number - tm.tm_wday + 7) % 7
                         + 7 * (pc.day_ordinal
                                - (0 < pc.day_ordinal
                                   && tm.tm_wday != pc.day_number)));
          tm.tm_isdst = -1;
          Start = mktime_z (tz, &tm);
          if (Start == (time_t) -1)
            {
              if (pc.parse_datetime_debug)
                dbg_printf (_("error: day '%s' (day ordinal=%ld number=%d) "   \
                              "resulted in an invalid date: '%s'\n"),
                            str_days (&pc,dbg_ord,sizeof (dbg_ord)),
                            pc.day_ordinal,pc.day_number,
                            debug_strfdatetime (&tm, &pc, dbg_tm,
                                                sizeof (dbg_tm)));

              goto fail;
            }

          if (pc.parse_datetime_debug)
            dbg_printf (_("new start date: '%s' is '%s'\n"),
                        str_days (&pc,dbg_ord,sizeof (dbg_ord)),
                        debug_strfdatetime (&tm, &pc, dbg_tm,sizeof (dbg_tm)));

        }

      if (pc.parse_datetime_debug)
        {
          if (!pc.dates_seen && !pc.days_seen)
            dbg_printf (_("using current date as starting value: '%s'\n"),
                        debug_strfdate (&tm,dbg_tm,sizeof (dbg_tm)));

          if (pc.days_seen && pc.dates_seen)
            dbg_printf (_("warning: day (%s) ignored when explicit dates " \
                          "are given\n"),
                        str_days (&pc,dbg_ord,sizeof (dbg_ord)));

          dbg_printf (_("starting date/time: '%s'\n"),
                      debug_strfdatetime (&tm, &pc, dbg_tm,sizeof (dbg_tm)));
        }

      /* Add relative date.  */
      if (pc.rel.year | pc.rel.month | pc.rel.day)
        {
          if (pc.parse_datetime_debug)
            {
              if ((pc.rel.year != 0 || pc.rel.month !=0) && tm.tm_mday!=15)
                dbg_printf (_("warning: when adding relative months/years, " \
                              "it is recommended to specify the 15th of the " \
                              "months\n"));

              if (pc.rel.day != 0 && tm.tm_hour!=12)
                dbg_printf (_("warning: when adding relative days, "    \
                              "it is recommended to specify 12:00pm\n"));
            }

          int year = tm.tm_year + pc.rel.year;
          int month = tm.tm_mon + pc.rel.month;
          int day = tm.tm_mday + pc.rel.day;
          if (((year < tm.tm_year) ^ (pc.rel.year < 0))
              | ((month < tm.tm_mon) ^ (pc.rel.month < 0))
              | ((day < tm.tm_mday) ^ (pc.rel.day < 0)))
            {
              /* TODO: what is the actual error? int-value wrap-around? */
              if (pc.parse_datetime_debug)
                dbg_printf (_("error: %s:%d\n"), __FILE__,__LINE__);

              goto fail;
            }
          tm.tm_year = year;
          tm.tm_mon = month;
          tm.tm_mday = day;
          tm.tm_hour = tm0.tm_hour;
          tm.tm_min = tm0.tm_min;
          tm.tm_sec = tm0.tm_sec;
          tm.tm_isdst = tm0.tm_isdst;
          Start = mktime_z (tz, &tm);
          if (Start == (time_t) -1)
            {
              if (pc.parse_datetime_debug)
                dbg_printf(_("error: adding relative date resulted " \
                             "in an invalid date: '%s'\n"),
                           debug_strfdatetime (&tm, &pc, dbg_tm,
                                               sizeof (dbg_tm)));

              goto fail;
            }

          if (pc.parse_datetime_debug)
            {
              dbg_printf (_("after date adjustment "                    \
                            "(%+ld years, %+ld months, %+ld days),\n"),
                          pc.rel.year, pc.rel.month, pc.rel.day);
              dbg_printf (_("    new date/time = '%s'\n"),
                          debug_strfdatetime (&tm, &pc, dbg_tm,
                                              sizeof (dbg_tm)));

              /* warn about crossing DST due to time adjustment.
                 Example: https://bugs.gnu.org/8357
                 env TZ=Europe/Helsinki \
                   date --debug \
                        -d 'Mon Mar 28 00:36:07 2011 EEST 1 day ago'

                 This case is different than DST changes due to time adjustment,
                 i.e. "1 day ago" vs "24 hours ago" are calculated in different
                 places.

                 'tm0.tm_isdst' contains the DST of the input date,
                 'tm.tm_isdst' is the normalized result after calling
                 mktime(&tm).
              */
              if ((tm0.tm_isdst!=-1) && (tm.tm_isdst != tm0.tm_isdst))
                dbg_printf (_("warning: daylight saving time changed after " \
                              "date adjustment\n"));

              /* warn if the user did not ask to adjust days but mday changed,
                 or
                 user did not ask to adjust months/days but the month changed.

                 Example for first case:
                 2016-05-31 + 1 month => 2016-06-31 => 2016-07-01.
                 User asked to adjust month, but the day changed from 31 to 01.

                 Example for second case:
                 2016-02-29 + 1 year => 2017-02-29 => 2017-03-01.
                 User asked to adjust year, but the month changed from 02 to 03.
              */
              if (((pc.rel.day==0) && (tm.tm_mday != day))
                  || ((pc.rel.day==0) && (pc.rel.month==0)
                      && (tm.tm_mon != month)))
                {
                  dbg_printf (_("warning: month/year adjustment resulted in "\
                                "shifted dates:\n"));
                  dbg_printf (_("     adjusted Y M D: %04d %02d %02d\n"),
                              year+1900, month+1, day);
                  dbg_printf (_("   normalized Y M D: %04d %02d %02d\n"),
                              tm.tm_year+1900, tm.tm_mon+1, tm.tm_mday);
                }
            }

        }

      /* The only "output" of this if-block is an updated Start value,
         so this block must follow others that clobber Start.  */
      if (pc.zones_seen)
        {
          long int delta = pc.time_zone * 60;
          time_t t1;
#ifdef HAVE_TM_GMTOFF
          delta -= tm.tm_gmtoff;
#else
          time_t t = Start;
          struct tm gmt;
          if (! gmtime_r (&t, &gmt))
            {
              /* TODO: use 'warn(3)' + print errno ? */
              if (pc.parse_datetime_debug)
                dbg_printf (_("error: gmtime failed for t=%ld\n"),t);

              goto fail;
            }
          delta -= tm_diff (&tm, &gmt);
#endif
          t1 = Start - delta;
          if ((Start < t1) != (delta < 0))
            {
              if (pc.parse_datetime_debug)
                dbg_printf (_("error: timezone %ld caused time_t overflow\n"),
                            pc.time_zone);

              goto fail;  /* time_t overflow */
            }
          Start = t1;
        }

      if (pc.parse_datetime_debug)
        dbg_printf (_("'%s' = %ld epoch-seconds\n"),
                    debug_strfdatetime (&tm, &pc, dbg_tm, sizeof (dbg_tm)),
                    Start);

      /* Add relative hours, minutes, and seconds.  On hosts that support
         leap seconds, ignore the possibility of leap seconds; e.g.,
         "+ 10 minutes" adds 600 seconds, even if one of them is a
         leap second.  Typically this is not what the user wants, but it's
         too hard to do it the other way, because the time zone indicator
         must be applied before relative times, and if mktime is applied
         again the time zone will be lost.  */
      {
        long int sum_ns = pc.seconds.tv_nsec + pc.rel.ns;
        long int normalized_ns = (sum_ns % BILLION + BILLION) % BILLION;
        time_t t0 = Start;
        long int d1 = 60 * 60 * pc.rel.hour;
        time_t t1 = t0 + d1;
        long int d2 = 60 * pc.rel.minutes;
        time_t t2 = t1 + d2;
        long_time_t d3 = pc.rel.seconds;
        long_time_t t3 = t2 + d3;
        long int d4 = (sum_ns - normalized_ns) / BILLION;
        long_time_t t4 = t3 + d4;
        time_t t5 = t4;

        if ((d1 / (60 * 60) ^ pc.rel.hour)
            | (d2 / 60 ^ pc.rel.minutes)
            | ((t1 < t0) ^ (d1 < 0))
            | ((t2 < t1) ^ (d2 < 0))
            | ((t3 < t2) ^ (d3 < 0))
            | ((t4 < t3) ^ (d4 < 0))
            | (t5 != t4))
            {
              if (pc.parse_datetime_debug)
                dbg_printf (_("error: adding relative time caused an " \
                              "overflow\n"));

              goto fail;
            }

          if (pc.parse_datetime_debug
              && (pc.rel.hour | pc.rel.minutes | pc.rel.seconds | pc.rel.ns))
            {
              struct tm lmt;
              dbg_printf (_("after time adjustment (%+ld hours, " \
                            "%+ld minutes, %+ld seconds, %+ld ns),\n"),
                          pc.rel.hour,pc.rel.minutes,pc.rel.seconds,pc.rel.ns);
              dbg_printf (_("    new time = %ld epoch-seconds\n"),t5);

              /* warn about crossing DST due to time adjustment.
                 Example: https://bugs.gnu.org/8357
                 env TZ=Europe/Helsinki \
                   date --debug \
                        -d 'Mon Mar 28 00:36:07 2011 EEST 24 hours ago'

                 This case is different than DST changes due to days adjustment,
                 i.e. "1 day ago" vs "24 hours ago" are calculated in different
                 places.

                 'tm.tm_isdst' contains the date after date adjustment.
              */
              if (tm.tm_isdst != -1 && localtime_rz (tz, &t5, &lmt)
                  && tm.tm_isdst != lmt.tm_isdst)
                dbg_printf (_("warning: daylight saving time changed after " \
                              "time adjustment\n"));
            }

        result->tv_sec = t5;
        result->tv_nsec = normalized_ns;
      }
    }

  goto done;

 fail:
  ok = false;
 done:
  if (ok && pc.parse_datetime_debug)
    {
      const long int otz = get_effective_timezone (tz);
      const char *tz_src;

      if (tzstring)
        {
          /* Special case: using 'date -u' simply set TZ=UTC0 */
          if (STREQ (tzstring, "UTC0"))
            {
              tz_src = _("TZ=UTC0 environment value or -u");
            }
          else
            {
              snprintf (dbg_tm, sizeof(dbg_tm),
                        _("TZ=\"%s\" environment value"), tzstring);
              tz_src = dbg_tm;
            }
        }
      else
        {
          tz_src = _("system default");
        }

      if (pc.parse_datetime_debug)
        {
          dbg_printf (_("output timezone: %+03d:%02d (set from %s)\n"),
                      (int)(otz/60), abs ((int)otz)%60, tz_src);


          dbg_printf (_("final: %ld.%09ld (epoch-seconds)\n"),
                      result->tv_sec,result->tv_nsec);

          struct tm gmt, lmt;
          if (gmtime_r (&result->tv_sec, &gmt))
            dbg_printf (_("final: %s (UTC0)\n"),
                        debug_strfdatetime (&gmt, NULL,
                                            dbg_tm, sizeof dbg_tm));
          if (localtime_rz (tz, &result->tv_sec, &lmt))
            dbg_printf (_("final: %s (output timezone TZ=%+03d:%02d)\n"),
                        debug_strfdatetime (&lmt, NULL, dbg_tm, sizeof dbg_tm),
                        (int) (otz / 60), abs ((int) (otz % 60)));
        }
    }

  if (tz != tzdefault)
    tzfree (tz);
  free (tz1alloc);
  return ok;
}

#if TEST

int
main (int ac, char **av)
{
  char buff[BUFSIZ];

  printf ("Enter date, or blank line to exit.\n\t> ");
  fflush (stdout);

  buff[BUFSIZ - 1] = '\0';
  while (fgets (buff, BUFSIZ - 1, stdin) && buff[0])
    {
      struct timespec d;
      struct tm const *tm;
      if (! parse_datetime (&d, buff, NULL))
        printf ("Bad format - couldn't convert.\n");
      else if (! (tm = localtime (&d.tv_sec)))
        {
          long int sec = d.tv_sec;
          printf ("localtime (%ld) failed\n", sec);
        }
      else
        {
          int ns = d.tv_nsec;
          printf ("%04ld-%02d-%02d %02d:%02d:%02d.%09d\n",
                  tm->tm_year + 1900L, tm->tm_mon + 1, tm->tm_mday,
                  tm->tm_hour, tm->tm_min, tm->tm_sec, ns);
        }
      printf ("\t> ");
      fflush (stdout);
    }
  return 0;
}
#endif /* TEST */
