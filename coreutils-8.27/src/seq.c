/* seq - print sequence of numbers to standard output.
   Copyright (C) 1994-2017 Free Software Foundation, Inc.

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

/* Written by Ulrich Drepper.  */

#include <config.h>
#include <getopt.h>
#include <stdio.h>
#include <sys/types.h>

#include "system.h"
#include "die.h"
#include "c-strtod.h"
#include "error.h"
#include "quote.h"
#include "xstrtod.h"

/* Roll our own isfinite/isnan rather than using <math.h>, so that we don't
   have to worry about linking -lm just for isfinite.  */
#ifndef isfinite
# define isfinite(x) ((x) * 0 == 0)
#endif
#ifndef isnan
# define isnan(x) ((x) != (x))
#endif

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "seq"

#define AUTHORS proper_name ("Ulrich Drepper")

/* If true print all number with equal width.  */
static bool equal_width;

/* The string used to separate two numbers.  */
static char const *separator;

/* The string output after all numbers have been output.
   Usually "\n" or "\0".  */
static char const terminator[] = "\n";

static struct option const long_options[] =
{
  { "equal-width", no_argument, NULL, 'w'},
  { "format", required_argument, NULL, 'f'},
  { "separator", required_argument, NULL, 's'},
  {GETOPT_HELP_OPTION_DECL},
  {GETOPT_VERSION_OPTION_DECL},
  { NULL, 0, NULL, 0}
};

void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("\
Usage: %s [OPTION]... LAST\n\
  or:  %s [OPTION]... FIRST LAST\n\
  or:  %s [OPTION]... FIRST INCREMENT LAST\n\
"), program_name, program_name, program_name);
      fputs (_("\
Print numbers from FIRST to LAST, in steps of INCREMENT.\n\
"), stdout);

      emit_mandatory_arg_note ();

      fputs (_("\
  -f, --format=FORMAT      use printf style floating-point FORMAT\n\
  -s, --separator=STRING   use STRING to separate numbers (default: \\n)\n\
  -w, --equal-width        equalize width by padding with leading zeroes\n\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      fputs (_("\
\n\
If FIRST or INCREMENT is omitted, it defaults to 1.  That is, an\n\
omitted INCREMENT defaults to 1 even when LAST is smaller than FIRST.\n\
The sequence of numbers ends when the sum of the current number and\n\
INCREMENT would become greater than LAST.\n\
FIRST, INCREMENT, and LAST are interpreted as floating point values.\n\
INCREMENT is usually positive if FIRST is smaller than LAST, and\n\
INCREMENT is usually negative if FIRST is greater than LAST.\n\
INCREMENT must not be 0; none of FIRST, INCREMENT and LAST may be NaN.\n\
"), stdout);
      fputs (_("\
FORMAT must be suitable for printing one argument of type 'double';\n\
it defaults to %.PRECf if FIRST, INCREMENT, and LAST are all fixed point\n\
decimal numbers with maximum precision PREC, and to %g otherwise.\n\
"), stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

/* A command-line operand.  */
struct operand
{
  /* Its value, converted to 'long double'.  */
  long double value;

  /* Its print width, if it were printed out in a form similar to its
     input form.  An input like "-.1" is treated like "-0.1", and an
     input like "1." is treated like "1", but otherwise widths are
     left alone.  */
  size_t width;

  /* Number of digits after the decimal point, or INT_MAX if the
     number can't easily be expressed as a fixed-point number.  */
  int precision;
};
typedef struct operand operand;

/* Description of what a number-generating format will generate.  */
struct layout
{
  /* Number of bytes before and after the number.  */
  size_t prefix_len;
  size_t suffix_len;
};

/* Read a long double value from the command line.
   Return if the string is correct else signal error.  */

static operand
scan_arg (const char *arg)
{
  operand ret;

  if (! xstrtold (arg, NULL, &ret.value, c_strtold))
    {
      error (0, 0, _("invalid floating point argument: %s"), quote (arg));
      usage (EXIT_FAILURE);
    }

  if (isnan (ret.value))
    {
      error (0, 0, _("invalid %s argument: %s"), quote_n (0, "not-a-number"),
             quote_n (1, arg));
      usage (EXIT_FAILURE);
    }

  /* We don't output spaces or '+' so don't include in width */
  while (isspace (to_uchar (*arg)) || *arg == '+')
    arg++;

  /* Default to auto width and precision.  */
  ret.width = 0;
  ret.precision = INT_MAX;

  /* Use no precision (and possibly fast generation) for integers.  */
  char const *decimal_point = strchr (arg, '.');
  if (! decimal_point && ! strchr (arg, 'p') /* not a hex float */)
    ret.precision = 0;

  /* auto set width and precision for decimal inputs.  */
  if (! arg[strcspn (arg, "xX")] && isfinite (ret.value))
    {
      size_t fraction_len = 0;
      ret.width = strlen (arg);

      if (decimal_point)
        {
          fraction_len = strcspn (decimal_point + 1, "eE");
          if (fraction_len <= INT_MAX)
            ret.precision = fraction_len;
          ret.width += (fraction_len == 0                      /* #.  -> #   */
                        ? -1
                        : (decimal_point == arg                /* .#  -> 0.# */
                           || ! ISDIGIT (decimal_point[-1]))); /* -.# -> 0.# */
        }
      char const *e = strchr (arg, 'e');
      if (! e)
        e = strchr (arg, 'E');
      if (e)
        {
          long exponent = strtol (e + 1, NULL, 10);
          ret.precision += exponent < 0 ? -exponent
                                        : - MIN (ret.precision, exponent);
          /* Don't account for e.... in the width since this is not output.  */
          ret.width -= strlen (arg) - (e - arg);
          /* Adjust the width as per the exponent.  */
          if (exponent < 0)
            {
              if (decimal_point)
                {
                  if (e == decimal_point + 1) /* undo #. -> # above  */
                    ret.width++;
                }
              else
                ret.width++;
              exponent = -exponent;
            }
          else
            {
              if (decimal_point && ret.precision == 0 && fraction_len)
                ret.width--; /* discount space for '.'  */
              exponent -= MIN (fraction_len, exponent);
            }
          ret.width += exponent;
        }
    }

  return ret;
}

/* If FORMAT is a valid printf format for a double argument, return
   its long double equivalent, allocated from dynamic storage, and
   store into *LAYOUT a description of the output layout; otherwise,
   report an error and exit.  */

static char const *
long_double_format (char const *fmt, struct layout *layout)
{
  size_t i;
  size_t prefix_len = 0;
  size_t suffix_len = 0;
  size_t length_modifier_offset;
  bool has_L;

  for (i = 0; ! (fmt[i] == '%' && fmt[i + 1] != '%'); i += (fmt[i] == '%') + 1)
    {
      if (!fmt[i])
        die (EXIT_FAILURE, 0,
             _("format %s has no %% directive"), quote (fmt));
      prefix_len++;
    }

  i++;
  i += strspn (fmt + i, "-+#0 '");
  i += strspn (fmt + i, "0123456789");
  if (fmt[i] == '.')
    {
      i++;
      i += strspn (fmt + i, "0123456789");
    }

  length_modifier_offset = i;
  has_L = (fmt[i] == 'L');
  i += has_L;
  if (fmt[i] == '\0')
    die (EXIT_FAILURE, 0, _("format %s ends in %%"), quote (fmt));
  if (! strchr ("efgaEFGA", fmt[i]))
    die (EXIT_FAILURE, 0,
         _("format %s has unknown %%%c directive"), quote (fmt), fmt[i]);

  for (i++; ; i += (fmt[i] == '%') + 1)
    if (fmt[i] == '%' && fmt[i + 1] != '%')
      die (EXIT_FAILURE, 0, _("format %s has too many %% directives"),
           quote (fmt));
    else if (fmt[i])
      suffix_len++;
    else
      {
        size_t format_size = i + 1;
        char *ldfmt = xmalloc (format_size + 1);
        memcpy (ldfmt, fmt, length_modifier_offset);
        ldfmt[length_modifier_offset] = 'L';
        strcpy (ldfmt + length_modifier_offset + 1,
                fmt + length_modifier_offset + has_L);
        layout->prefix_len = prefix_len;
        layout->suffix_len = suffix_len;
        return ldfmt;
      }
}

static void ATTRIBUTE_NORETURN
io_error (void)
{
  /* FIXME: consider option to silently ignore errno=EPIPE */
  clearerr (stdout);
  die (EXIT_FAILURE, errno, _("standard output"));
}

/* Actually print the sequence of numbers in the specified range, with the
   given or default stepping and format.  */

static void
print_numbers (char const *fmt, struct layout layout,
               long double first, long double step, long double last)
{
  bool out_of_range = (step < 0 ? first < last : last < first);

  if (! out_of_range)
    {
      long double x = first;
      long double i;

      for (i = 1; ; i++)
        {
          long double x0 = x;
          if (printf (fmt, x) < 0)
            io_error ();
          if (out_of_range)
            break;
          x = first + i * step;
          out_of_range = (step < 0 ? x < last : last < x);

          if (out_of_range)
            {
              /* If the number just past LAST prints as a value equal
                 to LAST, and prints differently from the previous
                 number, then print the number.  This avoids problems
                 with rounding.  For example, with the x86 it causes
                 "seq 0 0.000001 0.000003" to print 0.000003 instead
                 of stopping at 0.000002.  */

              bool print_extra_number = false;
              long double x_val;
              char *x_str;
              int x_strlen;
              setlocale (LC_NUMERIC, "C");
              x_strlen = asprintf (&x_str, fmt, x);
              setlocale (LC_NUMERIC, "");
              if (x_strlen < 0)
                xalloc_die ();
              x_str[x_strlen - layout.suffix_len] = '\0';

              if (xstrtold (x_str + layout.prefix_len, NULL, &x_val, c_strtold)
                  && x_val == last)
                {
                  char *x0_str = NULL;
                  if (asprintf (&x0_str, fmt, x0) < 0)
                    xalloc_die ();
                  print_extra_number = !STREQ (x0_str, x_str);
                  free (x0_str);
                }

              free (x_str);
              if (! print_extra_number)
                break;
            }

          if (fputs (separator, stdout) == EOF)
            io_error ();
        }

      if (fputs (terminator, stdout) == EOF)
        io_error ();
    }
}

/* Return the default format given FIRST, STEP, and LAST.  */
static char const *
get_default_format (operand first, operand step, operand last)
{
  static char format_buf[sizeof "%0.Lf" + 2 * INT_STRLEN_BOUND (int)];

  int prec = MAX (first.precision, step.precision);

  if (prec != INT_MAX && last.precision != INT_MAX)
    {
      if (equal_width)
        {
          /* increase first_width by any increased precision in step */
          size_t first_width = first.width + (prec - first.precision);
          /* adjust last_width to use precision from first/step */
          size_t last_width = last.width + (prec - last.precision);
          if (last.precision && prec == 0)
            last_width--;  /* don't include space for '.' */
          if (last.precision == 0 && prec)
            last_width++;  /* include space for '.' */
          if (first.precision == 0 && prec)
            first_width++;  /* include space for '.' */
          size_t width = MAX (first_width, last_width);
          if (width <= INT_MAX)
            {
              int w = width;
              sprintf (format_buf, "%%0%d.%dLf", w, prec);
              return format_buf;
            }
        }
      else
        {
          sprintf (format_buf, "%%.%dLf", prec);
          return format_buf;
        }
    }

  return "%Lg";
}

/* The NUL-terminated string S0 of length S_LEN represents a valid
   non-negative decimal integer.  Adjust the string and length so
   that the pair describe the next-larger value.  */
static void
incr (char **s0, size_t *s_len)
{
  char *s = *s0;
  char *endp = s + *s_len - 1;

  do
    {
      if ((*endp)++ < '9')
        return;
      *endp-- = '0';
    }
  while (endp >= s);
  *--(*s0) = '1';
  ++*s_len;
}

/* Compare A and B (each a NUL-terminated digit string), with lengths
   given by A_LEN and B_LEN.  Return +1 if A < B, -1 if B < A, else 0.  */
static int
cmp (char const *a, size_t a_len, char const *b, size_t b_len)
{
  if (a_len < b_len)
    return -1;
  if (b_len < a_len)
    return 1;
  return (strcmp (a, b));
}

/* Trim leading 0's from S, but if S is all 0's, leave one.
   Return a pointer to the trimmed string.  */
static char const * _GL_ATTRIBUTE_PURE
trim_leading_zeros (char const *s)
{
  char const *p = s;
  while (*s == '0')
    ++s;

  /* If there were only 0's, back up, to leave one.  */
  if (!*s && s != p)
    --s;
  return s;
}

/* Print all whole numbers from A to B, inclusive -- to stdout, each
   followed by a newline.  If B < A, return false and print nothing.
   Otherwise, return true.  */
static bool
seq_fast (char const *a, char const *b)
{
  bool inf = STREQ (b, "inf");

  /* Skip past any leading 0's.  Without this, our naive cmp
     function would declare 000 to be larger than 99.  */
  a = trim_leading_zeros (a);
  b = trim_leading_zeros (b);

  size_t p_len = strlen (a);
  size_t q_len = inf ? 0 : strlen (b);

  /* Allow for at least 31 digits without realloc.
     1 more than p_len is needed for the inf case.  */
  size_t inc_size = MAX (MAX (p_len + 1, q_len), 31);

  /* Copy input strings (incl NUL) to end of new buffers.  */
  char *p0 = xmalloc (inc_size + 1);
  char *p = memcpy (p0 + inc_size - p_len, a, p_len + 1);
  char *q;
  char *q0;
  if (! inf)
    {
      q0 = xmalloc (inc_size + 1);
      q = memcpy (q0 + inc_size - q_len, b, q_len + 1);
    }
  else
    q = q0 = NULL;

  bool ok = inf || cmp (p, p_len, q, q_len) <= 0;
  if (ok)
    {
      /* Reduce number of fwrite calls which is seen to
         give a speed-up of more than 2x over the unbuffered code
         when printing the first 10^9 integers.  */
      size_t buf_size = MAX (BUFSIZ, (inc_size + 1) * 2);
      char *buf = xmalloc (buf_size);
      char const *buf_end = buf + buf_size;

      char *bufp = buf;

      /* Write first number to buffer.  */
      bufp = mempcpy (bufp, p, p_len);

      /* Append separator then number.  */
      while (inf || cmp (p, p_len, q, q_len) < 0)
        {
          *bufp++ = *separator;
          incr (&p, &p_len);

          /* Double up the buffers when needed for the inf case.  */
          if (p_len == inc_size)
            {
              inc_size *= 2;
              p0 = xrealloc (p0, inc_size + 1);
              p = memmove (p0 + p_len, p0, p_len + 1);

              if (buf_size < (inc_size + 1) * 2)
                {
                  size_t buf_offset = bufp - buf;
                  buf_size = (inc_size + 1) * 2;
                  buf = xrealloc (buf, buf_size);
                  buf_end = buf + buf_size;
                  bufp = buf + buf_offset;
                }
            }

          bufp = mempcpy (bufp, p, p_len);
          /* If no place for another separator + number then
             output buffer so far, and reset to start of buffer.  */
          if (buf_end - (p_len + 1) < bufp)
            {
              if (fwrite (buf, bufp - buf, 1, stdout) != 1)
                io_error ();
              bufp = buf;
            }
        }

      /* Write any remaining buffered output, and the terminator.  */
      *bufp++ = *terminator;
      if (fwrite (buf, bufp - buf, 1, stdout) != 1)
        io_error ();

      IF_LINT (free (buf));
    }

  free (p0);
  free (q0);
  return ok;
}

/* Return true if S consists of at least one digit and no non-digits.  */
static bool _GL_ATTRIBUTE_PURE
all_digits_p (char const *s)
{
  size_t n = strlen (s);
  return ISDIGIT (s[0]) && n == strspn (s, "0123456789");
}

int
main (int argc, char **argv)
{
  int optc;
  operand first = { 1, 1, 0 };
  operand step = { 1, 1, 0 };
  operand last;
  struct layout layout = { 0, 0 };

  /* The printf(3) format used for output.  */
  char const *format_str = NULL;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  equal_width = false;
  separator = "\n";

  /* We have to handle negative numbers in the command line but this
     conflicts with the command line arguments.  So explicitly check first
     whether the next argument looks like a negative number.  */
  while (optind < argc)
    {
      if (argv[optind][0] == '-'
          && ((optc = argv[optind][1]) == '.' || ISDIGIT (optc)))
        {
          /* means negative number */
          break;
        }

      optc = getopt_long (argc, argv, "+f:s:w", long_options, NULL);
      if (optc == -1)
        break;

      switch (optc)
        {
        case 'f':
          format_str = optarg;
          break;

        case 's':
          separator = optarg;
          break;

        case 'w':
          equal_width = true;
          break;

        case_GETOPT_HELP_CHAR;

        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);

        default:
          usage (EXIT_FAILURE);
        }
    }

  unsigned int n_args = argc - optind;
  if (n_args < 1)
    {
      error (0, 0, _("missing operand"));
      usage (EXIT_FAILURE);
    }

  if (3 < n_args)
    {
      error (0, 0, _("extra operand %s"), quote (argv[optind + 3]));
      usage (EXIT_FAILURE);
    }

  if (format_str)
    format_str = long_double_format (format_str, &layout);

  if (format_str != NULL && equal_width)
    {
      error (0, 0, _("format string may not be specified"
                     " when printing equal width strings"));
      usage (EXIT_FAILURE);
    }

  /* If the following hold:
     - no format string, [FIXME: relax this, eventually]
     - integer start (or no start)
     - integer end
     - increment == 1 or not specified [FIXME: relax this, eventually]
     then use the much more efficient integer-only code.  */
  if (all_digits_p (argv[optind])
      && (n_args == 1 || all_digits_p (argv[optind + 1]))
      && (n_args < 3 || (STREQ ("1", argv[optind + 1])
                         && all_digits_p (argv[optind + 2])))
      && !equal_width && !format_str && strlen (separator) == 1)
    {
      char const *s1 = n_args == 1 ? "1" : argv[optind];
      char const *s2 = argv[optind + (n_args - 1)];
      if (seq_fast (s1, s2))
        return EXIT_SUCCESS;

      /* Upon any failure, let the more general code deal with it.  */
    }

  last = scan_arg (argv[optind++]);

  if (optind < argc)
    {
      first = last;
      last = scan_arg (argv[optind++]);

      if (optind < argc)
        {
          step = last;
          if (step.value == 0)
            {
              error (0, 0, _("invalid Zero increment value: %s"),
                     quote (argv[optind-1]));
              usage (EXIT_FAILURE);
            }

          last = scan_arg (argv[optind++]);
        }
    }

  if ((isfinite (first.value) && first.precision == 0)
      && step.precision == 0 && last.precision == 0
      && 0 <= first.value && step.value == 1 && 0 <= last.value
      && !equal_width && !format_str && strlen (separator) == 1)
    {
      char *s1;
      char *s2;
      if (asprintf (&s1, "%0.Lf", first.value) < 0)
        xalloc_die ();
      if (! isfinite (last.value))
        s2 = xstrdup ("inf"); /* Ensure "inf" is used.  */
      else if (asprintf (&s2, "%0.Lf", last.value) < 0)
        xalloc_die ();

      if (*s1 != '-' && *s2 != '-' && seq_fast (s1, s2))
        {
          IF_LINT (free (s1));
          IF_LINT (free (s2));
          return EXIT_SUCCESS;
        }

      free (s1);
      free (s2);
      /* Upon any failure, let the more general code deal with it.  */
    }

  if (format_str == NULL)
    format_str = get_default_format (first, step, last);

  print_numbers (format_str, layout, first.value, step.value, last.value);

  return EXIT_SUCCESS;
}
