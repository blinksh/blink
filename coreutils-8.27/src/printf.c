/* printf - format and print data
   Copyright (C) 1990-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* Usage: printf format [argument...]

   A front end to the printf function that lets it be used from the shell.

   Backslash escapes:

   \" = double quote
   \\ = backslash
   \a = alert (bell)
   \b = backspace
   \c = produce no further output
   \e = escape
   \f = form feed
   \n = new line
   \r = carriage return
   \t = horizontal tab
   \v = vertical tab
   \ooo = octal number (ooo is 1 to 3 digits)
   \xhh = hexadecimal number (hhh is 1 to 2 digits)
   \uhhhh = 16-bit Unicode character (hhhh is 4 digits)
   \Uhhhhhhhh = 32-bit Unicode character (hhhhhhhh is 8 digits)

   Additional directive:

   %b = print an argument string, interpreting backslash escapes,
     except that octal escapes are of the form \0 or \0ooo.

   %q = print an argument string in a format that can be
     reused as shell input.  Escaped characters used the proposed
     POSIX $'' syntax supported by most shells.

   The 'format' argument is re-used as many times as necessary
   to convert all of the given arguments.

   David MacKenzie <djm@gnu.ai.mit.edu> */

#include <config.h>
#include <stdio.h>
#include <sys/types.h>

#include "system.h"
#include "c-strtod.h"
#include "die.h"
#include "error.h"
#include "quote.h"
#include "unicodeio.h"
#include "xprintf.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "printf"

#define AUTHORS proper_name ("David MacKenzie")

#define isodigit(c) ((c) >= '0' && (c) <= '7')
#define hextobin(c) ((c) >= 'a' && (c) <= 'f' ? (c) - 'a' + 10 : \
                     (c) >= 'A' && (c) <= 'F' ? (c) - 'A' + 10 : (c) - '0')
#define octtobin(c) ((c) - '0')

/* The value to return to the calling program.  */
static int exit_status;

/* True if the POSIXLY_CORRECT environment variable is set.  */
static bool posixly_correct;

/* This message appears in N_() here rather than just in _() below because
   the sole use would have been in a #define.  */
static char const *const cfcc_msg =
 N_("warning: %s: character(s) following character constant have been ignored");

void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("\
Usage: %s FORMAT [ARGUMENT]...\n\
  or:  %s OPTION\n\
"),
              program_name, program_name);
      fputs (_("\
Print ARGUMENT(s) according to FORMAT, or execute according to OPTION:\n\
\n\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      fputs (_("\
\n\
FORMAT controls the output as in C printf.  Interpreted sequences are:\n\
\n\
  \\\"      double quote\n\
"), stdout);
      fputs (_("\
  \\\\      backslash\n\
  \\a      alert (BEL)\n\
  \\b      backspace\n\
  \\c      produce no further output\n\
  \\e      escape\n\
  \\f      form feed\n\
  \\n      new line\n\
  \\r      carriage return\n\
  \\t      horizontal tab\n\
  \\v      vertical tab\n\
"), stdout);
      fputs (_("\
  \\NNN    byte with octal value NNN (1 to 3 digits)\n\
  \\xHH    byte with hexadecimal value HH (1 to 2 digits)\n\
  \\uHHHH  Unicode (ISO/IEC 10646) character with hex value HHHH (4 digits)\n\
  \\UHHHHHHHH  Unicode character with hex value HHHHHHHH (8 digits)\n\
"), stdout);
      fputs (_("\
  %%      a single %\n\
  %b      ARGUMENT as a string with '\\' escapes interpreted,\n\
          except that octal escapes are of the form \\0 or \\0NNN\n\
  %q      ARGUMENT is printed in a format that can be reused as shell input,\n\
          escaping non-printable characters with the proposed POSIX $'' syntax.\
\n\n\
and all C format specifications ending with one of diouxXfeEgGcs, with\n\
ARGUMENTs converted to proper type first.  Variable widths are handled.\n\
"), stdout);
      printf (USAGE_BUILTIN_WARNING, PROGRAM_NAME);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

static void
verify_numeric (const char *s, const char *end)
{
  if (errno)
    {
      error (0, errno, "%s", quote (s));
      exit_status = EXIT_FAILURE;
    }
  else if (*end)
    {
      if (s == end)
        error (0, 0, _("%s: expected a numeric value"), quote (s));
      else
        error (0, 0, _("%s: value not completely converted"), quote (s));
      exit_status = EXIT_FAILURE;
    }
}

#define STRTOX(TYPE, FUNC_NAME, LIB_FUNC_EXPR)				 \
static TYPE								 \
FUNC_NAME (char const *s)						 \
{									 \
  char *end;								 \
  TYPE val;								 \
                                                                         \
  if ((*s == '\"' || *s == '\'') && *(s + 1))				 \
    {									 \
      unsigned char ch = *++s;						 \
      val = ch;								 \
      /* If POSIXLY_CORRECT is not set, then give a warning that there	 \
         are characters following the character constant and that GNU	 \
         printf is ignoring those characters.  If POSIXLY_CORRECT *is*	 \
         set, then don't give the warning.  */				 \
      if (*++s != 0 && !posixly_correct)				 \
        error (0, 0, _(cfcc_msg), s);					 \
    }									 \
  else									 \
    {									 \
      errno = 0;							 \
      val = (LIB_FUNC_EXPR);						 \
      verify_numeric (s, end);						 \
    }									 \
  return val;								 \
}									 \

STRTOX (intmax_t,    vstrtoimax, strtoimax (s, &end, 0))
STRTOX (uintmax_t,   vstrtoumax, strtoumax (s, &end, 0))
STRTOX (long double, vstrtold,   c_strtold (s, &end))

/* Output a single-character \ escape.  */

static void
print_esc_char (char c)
{
  switch (c)
    {
    case 'a':			/* Alert. */
      putchar ('\a');
      break;
    case 'b':			/* Backspace. */
      putchar ('\b');
      break;
    case 'c':			/* Cancel the rest of the output. */
      exit (EXIT_SUCCESS);
      break;
    case 'e':			/* Escape. */
      putchar ('\x1B');
      break;
    case 'f':			/* Form feed. */
      putchar ('\f');
      break;
    case 'n':			/* New line. */
      putchar ('\n');
      break;
    case 'r':			/* Carriage return. */
      putchar ('\r');
      break;
    case 't':			/* Horizontal tab. */
      putchar ('\t');
      break;
    case 'v':			/* Vertical tab. */
      putchar ('\v');
      break;
    default:
      putchar (c);
      break;
    }
}

/* Print a \ escape sequence starting at ESCSTART.
   Return the number of characters in the escape sequence
   besides the backslash.
   If OCTAL_0 is nonzero, octal escapes are of the form \0ooo, where o
   is an octal digit; otherwise they are of the form \ooo.  */

static int
print_esc (const char *escstart, bool octal_0)
{
  const char *p = escstart + 1;
  int esc_value = 0;		/* Value of \nnn escape. */
  int esc_length;		/* Length of \nnn escape. */

  if (*p == 'x')
    {
      /* A hexadecimal \xhh escape sequence must have 1 or 2 hex. digits.  */
      for (esc_length = 0, ++p;
           esc_length < 2 && isxdigit (to_uchar (*p));
           ++esc_length, ++p)
        esc_value = esc_value * 16 + hextobin (*p);
      if (esc_length == 0)
        die (EXIT_FAILURE, 0, _("missing hexadecimal number in escape"));
      putchar (esc_value);
    }
  else if (isodigit (*p))
    {
      /* Parse \0ooo (if octal_0 && *p == '0') or \ooo (otherwise).
         Allow \ooo if octal_0 && *p != '0'; this is an undocumented
         extension to POSIX that is compatible with Bash 2.05b.  */
      for (esc_length = 0, p += octal_0 && *p == '0';
           esc_length < 3 && isodigit (*p);
           ++esc_length, ++p)
        esc_value = esc_value * 8 + octtobin (*p);
      putchar (esc_value);
    }
  else if (*p && strchr ("\"\\abcefnrtv", *p))
    print_esc_char (*p++);
  else if (*p == 'u' || *p == 'U')
    {
      char esc_char = *p;
      unsigned int uni_value;

      uni_value = 0;
      for (esc_length = (esc_char == 'u' ? 4 : 8), ++p;
           esc_length > 0;
           --esc_length, ++p)
        {
          if (! isxdigit (to_uchar (*p)))
            die (EXIT_FAILURE, 0, _("missing hexadecimal number in escape"));
          uni_value = uni_value * 16 + hextobin (*p);
        }

      /* A universal character name shall not specify a character short
         identifier in the range 00000000 through 00000020, 0000007F through
         0000009F, or 0000D800 through 0000DFFF inclusive. A universal
         character name shall not designate a character in the required
         character set.  */
      if ((uni_value <= 0x9f
           && uni_value != 0x24 && uni_value != 0x40 && uni_value != 0x60)
          || (uni_value >= 0xd800 && uni_value <= 0xdfff))
        die (EXIT_FAILURE, 0, _("invalid universal character name \\%c%0*x"),
             esc_char, (esc_char == 'u' ? 4 : 8), uni_value);

      print_unicode_char (stdout, uni_value, 0);
    }
  else
    {
      putchar ('\\');
      if (*p)
        {
          putchar (*p);
          p++;
        }
    }
  return p - escstart - 1;
}

/* Print string STR, evaluating \ escapes. */

static void
print_esc_string (const char *str)
{
  for (; *str; str++)
    if (*str == '\\')
      str += print_esc (str, true);
    else
      putchar (*str);
}

/* Evaluate a printf conversion specification.  START is the start of
   the directive, LENGTH is its length, and CONVERSION specifies the
   type of conversion.  LENGTH does not include any length modifier or
   the conversion specifier itself.  FIELD_WIDTH and PRECISION are the
   field width and precision for '*' values, if HAVE_FIELD_WIDTH and
   HAVE_PRECISION are true, respectively.  ARGUMENT is the argument to
   be formatted.  */

static void
print_direc (const char *start, size_t length, char conversion,
             bool have_field_width, int field_width,
             bool have_precision, int precision,
             char const *argument)
{
  char *p;		/* Null-terminated copy of % directive. */

  /* Create a null-terminated copy of the % directive, with an
     intmax_t-wide length modifier substituted for any existing
     integer length modifier.  */
  {
    char *q;
    char const *length_modifier;
    size_t length_modifier_len;

    switch (conversion)
      {
      case 'd': case 'i': case 'o': case 'u': case 'x': case 'X':
        length_modifier = PRIdMAX;
        length_modifier_len = sizeof PRIdMAX - 2;
        break;

      case 'a': case 'e': case 'f': case 'g':
      case 'A': case 'E': case 'F': case 'G':
        length_modifier = "L";
        length_modifier_len = 1;
        break;

      default:
        length_modifier = start;  /* Any valid pointer will do.  */
        length_modifier_len = 0;
        break;
      }

    p = xmalloc (length + length_modifier_len + 2);
    q = mempcpy (p, start, length);
    q = mempcpy (q, length_modifier, length_modifier_len);
    *q++ = conversion;
    *q = '\0';
  }

  switch (conversion)
    {
    case 'd':
    case 'i':
      {
        intmax_t arg = vstrtoimax (argument);
        if (!have_field_width)
          {
            if (!have_precision)
              xprintf (p, arg);
            else
              xprintf (p, precision, arg);
          }
        else
          {
            if (!have_precision)
              xprintf (p, field_width, arg);
            else
              xprintf (p, field_width, precision, arg);
          }
      }
      break;

    case 'o':
    case 'u':
    case 'x':
    case 'X':
      {
        uintmax_t arg = vstrtoumax (argument);
        if (!have_field_width)
          {
            if (!have_precision)
              xprintf (p, arg);
            else
              xprintf (p, precision, arg);
          }
        else
          {
            if (!have_precision)
              xprintf (p, field_width, arg);
            else
              xprintf (p, field_width, precision, arg);
          }
      }
      break;

    case 'a':
    case 'A':
    case 'e':
    case 'E':
    case 'f':
    case 'F':
    case 'g':
    case 'G':
      {
        long double arg = vstrtold (argument);
        if (!have_field_width)
          {
            if (!have_precision)
              xprintf (p, arg);
            else
              xprintf (p, precision, arg);
          }
        else
          {
            if (!have_precision)
              xprintf (p, field_width, arg);
            else
              xprintf (p, field_width, precision, arg);
          }
      }
      break;

    case 'c':
      if (!have_field_width)
        xprintf (p, *argument);
      else
        xprintf (p, field_width, *argument);
      break;

    case 's':
      if (!have_field_width)
        {
          if (!have_precision)
            xprintf (p, argument);
          else
            xprintf (p, precision, argument);
        }
      else
        {
          if (!have_precision)
            xprintf (p, field_width, argument);
          else
            xprintf (p, field_width, precision, argument);
        }
      break;
    }

  free (p);
}

/* Print the text in FORMAT, using ARGV (with ARGC elements) for
   arguments to any '%' directives.
   Return the number of elements of ARGV used.  */

static int
print_formatted (const char *format, int argc, char **argv)
{
  int save_argc = argc;		/* Preserve original value.  */
  const char *f;		/* Pointer into 'format'.  */
  const char *direc_start;	/* Start of % directive.  */
  size_t direc_length;		/* Length of % directive.  */
  bool have_field_width;	/* True if FIELD_WIDTH is valid.  */
  int field_width = 0;		/* Arg to first '*'.  */
  bool have_precision;		/* True if PRECISION is valid.  */
  int precision = 0;		/* Arg to second '*'.  */
  char ok[UCHAR_MAX + 1];	/* ok['x'] is true if %x is allowed.  */

  for (f = format; *f; ++f)
    {
      switch (*f)
        {
        case '%':
          direc_start = f++;
          direc_length = 1;
          have_field_width = have_precision = false;
          if (*f == '%')
            {
              putchar ('%');
              break;
            }
          if (*f == 'b')
            {
              /* FIXME: Field width and precision are not supported
                 for %b, even though POSIX requires it.  */
              if (argc > 0)
                {
                  print_esc_string (*argv);
                  ++argv;
                  --argc;
                }
              break;
            }

          if (*f == 'q')
            {
              if (argc > 0)
                {
                  fputs (quotearg_style (shell_escape_quoting_style, *argv),
                         stdout);
                  ++argv;
                  --argc;
                }
              break;
            }

          memset (ok, 0, sizeof ok);
          ok['a'] = ok['A'] = ok['c'] = ok['d'] = ok['e'] = ok['E'] =
            ok['f'] = ok['F'] = ok['g'] = ok['G'] = ok['i'] = ok['o'] =
            ok['s'] = ok['u'] = ok['x'] = ok['X'] = 1;

          for (;; f++, direc_length++)
            switch (*f)
              {
#if (__GLIBC__ == 2 && 2 <= __GLIBC_MINOR__) || 3 <= __GLIBC__
              case 'I':
#endif
              case '\'':
                ok['a'] = ok['A'] = ok['c'] = ok['e'] = ok['E'] =
                  ok['o'] = ok['s'] = ok['x'] = ok['X'] = 0;
                break;
              case '-': case '+': case ' ':
                break;
              case '#':
                ok['c'] = ok['d'] = ok['i'] = ok['s'] = ok['u'] = 0;
                break;
              case '0':
                ok['c'] = ok['s'] = 0;
                break;
              default:
                goto no_more_flag_characters;
              }
        no_more_flag_characters:

          if (*f == '*')
            {
              ++f;
              ++direc_length;
              if (argc > 0)
                {
                  intmax_t width = vstrtoimax (*argv);
                  if (INT_MIN <= width && width <= INT_MAX)
                    field_width = width;
                  else
                    die (EXIT_FAILURE, 0, _("invalid field width: %s"),
                         quote (*argv));
                  ++argv;
                  --argc;
                }
              else
                field_width = 0;
              have_field_width = true;
            }
          else
            while (ISDIGIT (*f))
              {
                ++f;
                ++direc_length;
              }
          if (*f == '.')
            {
              ++f;
              ++direc_length;
              ok['c'] = 0;
              if (*f == '*')
                {
                  ++f;
                  ++direc_length;
                  if (argc > 0)
                    {
                      intmax_t prec = vstrtoimax (*argv);
                      if (prec < 0)
                        {
                          /* A negative precision is taken as if the
                             precision were omitted, so -1 is safe
                             here even if prec < INT_MIN.  */
                          precision = -1;
                        }
                      else if (INT_MAX < prec)
                        die (EXIT_FAILURE, 0, _("invalid precision: %s"),
                             quote (*argv));
                      else
                        precision = prec;
                      ++argv;
                      --argc;
                    }
                  else
                    precision = 0;
                  have_precision = true;
                }
              else
                while (ISDIGIT (*f))
                  {
                    ++f;
                    ++direc_length;
                  }
            }

          while (*f == 'l' || *f == 'L' || *f == 'h'
                 || *f == 'j' || *f == 't' || *f == 'z')
            ++f;

          {
            unsigned char conversion = *f;
            if (! ok[conversion])
              die (EXIT_FAILURE, 0,
                   _("%.*s: invalid conversion specification"),
                   (int) (f + 1 - direc_start), direc_start);
          }

          print_direc (direc_start, direc_length, *f,
                       have_field_width, field_width,
                       have_precision, precision,
                       (argc <= 0 ? "" : (argc--, *argv++)));
          break;

        case '\\':
          f += print_esc (f, false);
          break;

        default:
          putchar (*f);
        }
    }

  return save_argc - argc;
}

int
main (int argc, char **argv)
{
  char *format;
  int args_used;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  exit_status = EXIT_SUCCESS;

  posixly_correct = (getenv ("POSIXLY_CORRECT") != NULL);

  /* We directly parse options, rather than use parse_long_options, in
     order to avoid accepting abbreviations.  */
  if (argc == 2)
    {
      if (STREQ (argv[1], "--help"))
        usage (EXIT_SUCCESS);

      if (STREQ (argv[1], "--version"))
        {
          version_etc (stdout, PROGRAM_NAME, PACKAGE_NAME, Version, AUTHORS,
                       (char *) NULL);
          return EXIT_SUCCESS;
        }
    }

  /* The above handles --help and --version.
     Since there is no other invocation of getopt, handle '--' here.  */
  if (1 < argc && STREQ (argv[1], "--"))
    {
      --argc;
      ++argv;
    }

  if (argc <= 1)
    {
      error (0, 0, _("missing operand"));
      usage (EXIT_FAILURE);
    }

  format = argv[1];
  argc -= 2;
  argv += 2;

  do
    {
      args_used = print_formatted (format, argc, argv);
      argc -= args_used;
      argv += args_used;
    }
  while (args_used > 0 && argc > 0);

  if (argc > 0)
    error (0, 0,
           _("warning: ignoring excess arguments, starting with %s"),
           quote (argv[0]));

  return exit_status;
}
