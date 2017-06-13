/* join - join lines of two files on a common field
   Copyright (C) 1991-2017 Free Software Foundation, Inc.

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

   Written by Mike Haertel, mike@gnu.ai.mit.edu.  */

#include <config.h>

#include <assert.h>
#include <sys/types.h>
#include <getopt.h>

#include "system.h"
#include "die.h"
#include "error.h"
#include "fadvise.h"
#include "hard-locale.h"
#include "linebuffer.h"
#include "memcasecmp.h"
#include "quote.h"
#include "stdio--.h"
#include "xmemcoll.h"
#include "xstrtol.h"
#include "argmatch.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "join"

#define AUTHORS proper_name ("Mike Haertel")

#define join system_join

#define SWAPLINES(a, b) do { \
  struct line *tmp = a; \
  a = b; \
  b = tmp; \
} while (0);

/* An element of the list identifying which fields to print for each
   output line.  */
struct outlist
  {
    /* File number: 0, 1, or 2.  0 means use the join field.
       1 means use the first file argument, 2 the second.  */
    int file;

    /* Field index (zero-based), specified only when FILE is 1 or 2.  */
    size_t field;

    struct outlist *next;
  };

/* A field of a line.  */
struct field
  {
    char *beg;			/* First character in field.  */
    size_t len;			/* The length of the field.  */
  };

/* A line read from an input file.  */
struct line
  {
    struct linebuffer buf;	/* The line itself.  */
    size_t nfields;		/* Number of elements in 'fields'.  */
    size_t nfields_allocated;	/* Number of elements allocated for 'fields'. */
    struct field *fields;
  };

/* One or more consecutive lines read from a file that all have the
   same join field value.  */
struct seq
  {
    size_t count;			/* Elements used in 'lines'.  */
    size_t alloc;			/* Elements allocated in 'lines'.  */
    struct line **lines;
  };

/* The previous line read from each file.  */
static struct line *prevline[2] = {NULL, NULL};

/* The number of lines read from each file.  */
static uintmax_t line_no[2] = {0, 0};

/* The input file names.  */
static char *g_names[2];

/* This provides an extra line buffer for each file.  We need these if we
   try to read two consecutive lines into the same buffer, since we don't
   want to overwrite the previous buffer before we check order. */
static struct line *spareline[2] = {NULL, NULL};

/* True if the LC_COLLATE locale is hard.  */
static bool hard_LC_COLLATE;

/* If nonzero, print unpairable lines in file 1 or 2.  */
static bool print_unpairables_1, print_unpairables_2;

/* If nonzero, print pairable lines.  */
static bool print_pairables;

/* If nonzero, we have seen at least one unpairable line. */
static bool seen_unpairable;

/* If nonzero, we have warned about disorder in that file. */
static bool issued_disorder_warning[2];

/* Empty output field filler.  */
static char const *empty_filler;

/* Whether to ensure the same number of fields are output from each line.  */
static bool autoformat;
/* The number of fields to output for each line.
   Only significant when autoformat is true.  */
static size_t autocount_1;
static size_t autocount_2;

/* Field to join on; SIZE_MAX means they haven't been determined yet.  */
static size_t join_field_1 = SIZE_MAX;
static size_t join_field_2 = SIZE_MAX;

/* List of fields to print.  */
static struct outlist outlist_head;

/* Last element in 'outlist', where a new element can be added.  */
static struct outlist *outlist_end = &outlist_head;

/* Tab character separating fields.  If negative, fields are separated
   by any nonempty string of blanks, otherwise by exactly one
   tab character whose value (when cast to unsigned char) equals TAB.  */
static int tab = -1;

/* If nonzero, check that the input is correctly ordered. */
static enum
  {
    CHECK_ORDER_DEFAULT,
    CHECK_ORDER_ENABLED,
    CHECK_ORDER_DISABLED
  } check_input_order;

enum
{
  CHECK_ORDER_OPTION = CHAR_MAX + 1,
  NOCHECK_ORDER_OPTION,
  HEADER_LINE_OPTION
};


static struct option const longopts[] =
{
  {"ignore-case", no_argument, NULL, 'i'},
  {"check-order", no_argument, NULL, CHECK_ORDER_OPTION},
  {"nocheck-order", no_argument, NULL, NOCHECK_ORDER_OPTION},
  {"zero-terminated", no_argument, NULL, 'z'},
  {"header", no_argument, NULL, HEADER_LINE_OPTION},
  {GETOPT_HELP_OPTION_DECL},
  {GETOPT_VERSION_OPTION_DECL},
  {NULL, 0, NULL, 0}
};

/* Used to print non-joining lines */
static struct line uni_blank;

/* If nonzero, ignore case when comparing join fields.  */
static bool ignore_case;

/* If nonzero, treat the first line of each file as column headers --
   join them without checking for ordering */
static bool join_header_lines;

/* The character marking end of line. Default to \n. */
static char eolchar = '\n';

void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("\
Usage: %s [OPTION]... FILE1 FILE2\n\
"),
              program_name);
      fputs (_("\
For each pair of input lines with identical join fields, write a line to\n\
standard output.  The default join field is the first, delimited by blanks.\
\n\
"), stdout);
      fputs (_("\
\n\
When FILE1 or FILE2 (not both) is -, read standard input.\n\
"), stdout);
      fputs (_("\
\n\
  -a FILENUM        also print unpairable lines from file FILENUM, where\n\
                      FILENUM is 1 or 2, corresponding to FILE1 or FILE2\n\
  -e EMPTY          replace missing input fields with EMPTY\n\
"), stdout);
      fputs (_("\
  -i, --ignore-case  ignore differences in case when comparing fields\n\
  -j FIELD          equivalent to '-1 FIELD -2 FIELD'\n\
  -o FORMAT         obey FORMAT while constructing output line\n\
  -t CHAR           use CHAR as input and output field separator\n\
"), stdout);
      fputs (_("\
  -v FILENUM        like -a FILENUM, but suppress joined output lines\n\
  -1 FIELD          join on this FIELD of file 1\n\
  -2 FIELD          join on this FIELD of file 2\n\
  --check-order     check that the input is correctly sorted, even\n\
                      if all input lines are pairable\n\
  --nocheck-order   do not check that the input is correctly sorted\n\
  --header          treat the first line in each file as field headers,\n\
                      print them without trying to pair them\n\
"), stdout);
      fputs (_("\
  -z, --zero-terminated     line delimiter is NUL, not newline\n\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      fputs (_("\
\n\
Unless -t CHAR is given, leading blanks separate fields and are ignored,\n\
else fields are separated by CHAR.  Any FIELD is a field number counted\n\
from 1.  FORMAT is one or more comma or blank separated specifications,\n\
each being 'FILENUM.FIELD' or '0'.  Default FORMAT outputs the join field,\n\
the remaining fields from FILE1, the remaining fields from FILE2, all\n\
separated by CHAR.  If FORMAT is the keyword 'auto', then the first\n\
line of each file determines the number of fields output for each line.\n\
\n\
Important: FILE1 and FILE2 must be sorted on the join fields.\n\
E.g., use \"sort -k 1b,1\" if 'join' has no options,\n\
or use \"join -t ''\" if 'sort' has no options.\n\
Note, comparisons honor the rules specified by 'LC_COLLATE'.\n\
If the input is not sorted and some lines cannot be joined, a\n\
warning message will be given.\n\
"), stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

/* Record a field in LINE, with location FIELD and size LEN.  */

static void
extract_field (struct line *line, char *field, size_t len)
{
  if (line->nfields >= line->nfields_allocated)
    {
      line->fields = X2NREALLOC (line->fields, &line->nfields_allocated);
    }
  line->fields[line->nfields].beg = field;
  line->fields[line->nfields].len = len;
  ++(line->nfields);
}

/* Fill in the 'fields' structure in LINE.  */

static void
xfields (struct line *line)
{
  char *ptr = line->buf.buffer;
  char const *lim = ptr + line->buf.length - 1;

  if (ptr == lim)
    return;

  if (0 <= tab && tab != '\n')
    {
      char *sep;
      for (; (sep = memchr (ptr, tab, lim - ptr)) != NULL; ptr = sep + 1)
        extract_field (line, ptr, sep - ptr);
    }
  else if (tab < 0)
    {
      /* Skip leading blanks before the first field.  */
      while (field_sep (*ptr))
        if (++ptr == lim)
          return;

      do
        {
          char *sep;
          for (sep = ptr + 1; sep != lim && ! field_sep (*sep); sep++)
            continue;
          extract_field (line, ptr, sep - ptr);
          if (sep == lim)
            return;
          for (ptr = sep + 1; ptr != lim && field_sep (*ptr); ptr++)
            continue;
        }
      while (ptr != lim);
    }

  extract_field (line, ptr, lim - ptr);
}

static void
freeline (struct line *line)
{
  if (line == NULL)
    return;
  free (line->fields);
  line->fields = NULL;
  free (line->buf.buffer);
  line->buf.buffer = NULL;
}

/* Return <0 if the join field in LINE1 compares less than the one in LINE2;
   >0 if it compares greater; 0 if it compares equal.
   Report an error and exit if the comparison fails.
   Use join fields JF_1 and JF_2 respectively.  */

static int
keycmp (struct line const *line1, struct line const *line2,
        size_t jf_1, size_t jf_2)
{
  /* Start of field to compare in each file.  */
  char *beg1;
  char *beg2;

  size_t len1;
  size_t len2;		/* Length of fields to compare.  */
  int diff;

  if (jf_1 < line1->nfields)
    {
      beg1 = line1->fields[jf_1].beg;
      len1 = line1->fields[jf_1].len;
    }
  else
    {
      beg1 = NULL;
      len1 = 0;
    }

  if (jf_2 < line2->nfields)
    {
      beg2 = line2->fields[jf_2].beg;
      len2 = line2->fields[jf_2].len;
    }
  else
    {
      beg2 = NULL;
      len2 = 0;
    }

  if (len1 == 0)
    return len2 == 0 ? 0 : -1;
  if (len2 == 0)
    return 1;

  if (ignore_case)
    {
      /* FIXME: ignore_case does not work with NLS (in particular,
         with multibyte chars).  */
      diff = memcasecmp (beg1, beg2, MIN (len1, len2));
    }
  else
    {
      if (hard_LC_COLLATE)
        return xmemcoll (beg1, len1, beg2, len2);
      diff = memcmp (beg1, beg2, MIN (len1, len2));
    }

  if (diff)
    return diff;
  return len1 < len2 ? -1 : len1 != len2;
}

/* Check that successive input lines PREV and CURRENT from input file
   WHATFILE are presented in order, unless the user may be relying on
   the GNU extension that input lines may be out of order if no input
   lines are unpairable.

   If the user specified --nocheck-order, the check is not made.
   If the user specified --check-order, the problem is fatal.
   Otherwise (the default), the message is simply a warning.

   A message is printed at most once per input file. */

static void
check_order (const struct line *prev,
             const struct line *current,
             int whatfile)
{
  if (check_input_order != CHECK_ORDER_DISABLED
      && ((check_input_order == CHECK_ORDER_ENABLED) || seen_unpairable))
    {
      if (!issued_disorder_warning[whatfile-1])
        {
          size_t join_field = whatfile == 1 ? join_field_1 : join_field_2;
          if (keycmp (prev, current, join_field, join_field) > 0)
            {
              /* Exclude any trailing newline. */
              size_t len = current->buf.length;
              if (0 < len && current->buf.buffer[len - 1] == '\n')
                --len;

              /* If the offending line is longer than INT_MAX, output
                 only the first INT_MAX bytes in this diagnostic.  */
              len = MIN (INT_MAX, len);

              error ((check_input_order == CHECK_ORDER_ENABLED
                      ? EXIT_FAILURE : 0),
                     0, _("%s:%"PRIuMAX": is not sorted: %.*s"),
                     g_names[whatfile - 1], line_no[whatfile - 1],
                     (int) len, current->buf.buffer);

              /* If we get to here, the message was merely a warning.
                 Arrange to issue it only once per file.  */
              issued_disorder_warning[whatfile-1] = true;
            }
        }
    }
}

static inline void
reset_line (struct line *line)
{
  line->nfields = 0;
}

static struct line *
init_linep (struct line **linep)
{
  struct line *line = xcalloc (1, sizeof *line);
  *linep = line;
  return line;
}

/* Read a line from FP into LINE and split it into fields.
   Return true if successful.  */

static bool
get_line (FILE *fp, struct line **linep, int which)
{
  struct line *line = *linep;

  if (line == prevline[which - 1])
    {
      SWAPLINES (line, spareline[which - 1]);
      *linep = line;
    }

  if (line)
    reset_line (line);
  else
    line = init_linep (linep);

  if (! readlinebuffer_delim (&line->buf, fp, eolchar))
    {
      if (ferror (fp))
        die (EXIT_FAILURE, errno, _("read error"));
      freeline (line);
      return false;
    }
  ++line_no[which - 1];

  xfields (line);

  if (prevline[which - 1])
    check_order (prevline[which - 1], line, which);

  prevline[which - 1] = line;
  return true;
}

static void
free_spareline (void)
{
  size_t i;

  for (i = 0; i < ARRAY_CARDINALITY (spareline); i++)
    {
      if (spareline[i])
        {
          freeline (spareline[i]);
          free (spareline[i]);
        }
    }
}

static void
initseq (struct seq *seq)
{
  seq->count = 0;
  seq->alloc = 0;
  seq->lines = NULL;
}

/* Read a line from FP and add it to SEQ.  Return true if successful.  */

static bool
getseq (FILE *fp, struct seq *seq, int whichfile)
{
  if (seq->count == seq->alloc)
    {
      size_t i;
      seq->lines = X2NREALLOC (seq->lines, &seq->alloc);
      for (i = seq->count; i < seq->alloc; i++)
        seq->lines[i] = NULL;
    }

  if (get_line (fp, &seq->lines[seq->count], whichfile))
    {
      ++seq->count;
      return true;
    }
  return false;
}

/* Read a line from FP and add it to SEQ, as the first item if FIRST is
   true, else as the next.  */
static bool
advance_seq (FILE *fp, struct seq *seq, bool first, int whichfile)
{
  if (first)
    seq->count = 0;

  return getseq (fp, seq, whichfile);
}

static void
delseq (struct seq *seq)
{
  size_t i;
  for (i = 0; i < seq->alloc; i++)
    {
      freeline (seq->lines[i]);
      free (seq->lines[i]);
    }
  free (seq->lines);
}


/* Print field N of LINE if it exists and is nonempty, otherwise
   'empty_filler' if it is nonempty.  */

static void
prfield (size_t n, struct line const *line)
{
  size_t len;

  if (n < line->nfields)
    {
      len = line->fields[n].len;
      if (len)
        fwrite (line->fields[n].beg, 1, len, stdout);
      else if (empty_filler)
        fputs (empty_filler, stdout);
    }
  else if (empty_filler)
    fputs (empty_filler, stdout);
}

/* Output all the fields in line, other than the join field.  */

static void
prfields (struct line const *line, size_t join_field, size_t autocount)
{
  size_t i;
  size_t nfields = autoformat ? autocount : line->nfields;
  char output_separator = tab < 0 ? ' ' : tab;

  for (i = 0; i < join_field && i < nfields; ++i)
    {
      putchar (output_separator);
      prfield (i, line);
    }
  for (i = join_field + 1; i < nfields; ++i)
    {
      putchar (output_separator);
      prfield (i, line);
    }
}

/* Print the join of LINE1 and LINE2.  */

static void
prjoin (struct line const *line1, struct line const *line2)
{
  const struct outlist *outlist;
  char output_separator = tab < 0 ? ' ' : tab;
  size_t field;
  struct line const *line;

  outlist = outlist_head.next;
  if (outlist)
    {
      const struct outlist *o;

      o = outlist;
      while (1)
        {
          if (o->file == 0)
            {
              if (line1 == &uni_blank)
                {
                  line = line2;
                  field = join_field_2;
                }
              else
                {
                  line = line1;
                  field = join_field_1;
                }
            }
          else
            {
              line = (o->file == 1 ? line1 : line2);
              field = o->field;
            }
          prfield (field, line);
          o = o->next;
          if (o == NULL)
            break;
          putchar (output_separator);
        }
      putchar (eolchar);
    }
  else
    {
      if (line1 == &uni_blank)
        {
          line = line2;
          field = join_field_2;
        }
      else
        {
          line = line1;
          field = join_field_1;
        }

      /* Output the join field.  */
      prfield (field, line);

      /* Output other fields.  */
      prfields (line1, join_field_1, autocount_1);
      prfields (line2, join_field_2, autocount_2);

      putchar (eolchar);
    }
}

/* Print the join of the files in FP1 and FP2.  */

static void
join (FILE *fp1, FILE *fp2)
{
  struct seq seq1, seq2;
  int diff;
  bool eof1, eof2;

  fadvise (fp1, FADVISE_SEQUENTIAL);
  fadvise (fp2, FADVISE_SEQUENTIAL);

  /* Read the first line of each file.  */
  initseq (&seq1);
  getseq (fp1, &seq1, 1);
  initseq (&seq2);
  getseq (fp2, &seq2, 2);

  if (autoformat)
    {
      autocount_1 = seq1.count ? seq1.lines[0]->nfields : 0;
      autocount_2 = seq2.count ? seq2.lines[0]->nfields : 0;
    }

  if (join_header_lines && (seq1.count || seq2.count))
    {
      struct line const *hline1 = seq1.count ? seq1.lines[0] : &uni_blank;
      struct line const *hline2 = seq2.count ? seq2.lines[0] : &uni_blank;
      prjoin (hline1, hline2);
      prevline[0] = NULL;
      prevline[1] = NULL;
      if (seq1.count)
        advance_seq (fp1, &seq1, true, 1);
      if (seq2.count)
        advance_seq (fp2, &seq2, true, 2);
    }

  while (seq1.count && seq2.count)
    {
      size_t i;
      diff = keycmp (seq1.lines[0], seq2.lines[0],
                     join_field_1, join_field_2);
      if (diff < 0)
        {
          if (print_unpairables_1)
            prjoin (seq1.lines[0], &uni_blank);
          advance_seq (fp1, &seq1, true, 1);
          seen_unpairable = true;
          continue;
        }
      if (diff > 0)
        {
          if (print_unpairables_2)
            prjoin (&uni_blank, seq2.lines[0]);
          advance_seq (fp2, &seq2, true, 2);
          seen_unpairable = true;
          continue;
        }

      /* Keep reading lines from file1 as long as they continue to
         match the current line from file2.  */
      eof1 = false;
      do
        if (!advance_seq (fp1, &seq1, false, 1))
          {
            eof1 = true;
            ++seq1.count;
            break;
          }
      while (!keycmp (seq1.lines[seq1.count - 1], seq2.lines[0],
                      join_field_1, join_field_2));

      /* Keep reading lines from file2 as long as they continue to
         match the current line from file1.  */
      eof2 = false;
      do
        if (!advance_seq (fp2, &seq2, false, 2))
          {
            eof2 = true;
            ++seq2.count;
            break;
          }
      while (!keycmp (seq1.lines[0], seq2.lines[seq2.count - 1],
                      join_field_1, join_field_2));

      if (print_pairables)
        {
          for (i = 0; i < seq1.count - 1; ++i)
            {
              size_t j;
              for (j = 0; j < seq2.count - 1; ++j)
                prjoin (seq1.lines[i], seq2.lines[j]);
            }
        }

      if (!eof1)
        {
          SWAPLINES (seq1.lines[0], seq1.lines[seq1.count - 1]);
          seq1.count = 1;
        }
      else
        seq1.count = 0;

      if (!eof2)
        {
          SWAPLINES (seq2.lines[0], seq2.lines[seq2.count - 1]);
          seq2.count = 1;
        }
      else
        seq2.count = 0;
    }

  /* If the user did not specify --nocheck-order, then we read the
     tail ends of both inputs to verify that they are in order.  We
     skip the rest of the tail once we have issued a warning for that
     file, unless we actually need to print the unpairable lines.  */
  struct line *line = NULL;
  bool checktail = false;

  if (check_input_order != CHECK_ORDER_DISABLED
      && !(issued_disorder_warning[0] && issued_disorder_warning[1]))
    checktail = true;

  if ((print_unpairables_1 || checktail) && seq1.count)
    {
      if (print_unpairables_1)
        prjoin (seq1.lines[0], &uni_blank);
      if (seq2.count)
        seen_unpairable = true;
      while (get_line (fp1, &line, 1))
        {
          if (print_unpairables_1)
            prjoin (line, &uni_blank);
          if (issued_disorder_warning[0] && !print_unpairables_1)
            break;
        }
    }

  if ((print_unpairables_2 || checktail) && seq2.count)
    {
      if (print_unpairables_2)
        prjoin (&uni_blank, seq2.lines[0]);
      if (seq1.count)
        seen_unpairable = true;
      while (get_line (fp2, &line, 2))
        {
          if (print_unpairables_2)
            prjoin (&uni_blank, line);
          if (issued_disorder_warning[1] && !print_unpairables_2)
            break;
        }
    }

  freeline (line);
  free (line);

  delseq (&seq1);
  delseq (&seq2);
}

/* Add a field spec for field FIELD of file FILE to 'outlist'.  */

static void
add_field (int file, size_t field)
{
  struct outlist *o;

  assert (file == 0 || file == 1 || file == 2);
  assert (file != 0 || field == 0);

  o = xmalloc (sizeof *o);
  o->file = file;
  o->field = field;
  o->next = NULL;

  /* Add to the end of the list so the fields are in the right order.  */
  outlist_end->next = o;
  outlist_end = o;
}

/* Convert a string of decimal digits, STR (the 1-based join field number),
   to an integral value.  Upon successful conversion, return one less
   (the zero-based field number).  Silently convert too-large values
   to SIZE_MAX - 1.  Otherwise, if a value cannot be converted, give a
   diagnostic and exit.  */

static size_t
string_to_join_field (char const *str)
{
  size_t result;
  unsigned long int val;
  verify (SIZE_MAX <= ULONG_MAX);

  strtol_error s_err = xstrtoul (str, NULL, 10, &val, "");
  if (s_err == LONGINT_OVERFLOW || (s_err == LONGINT_OK && SIZE_MAX < val))
    val = SIZE_MAX;
  else if (s_err != LONGINT_OK || val == 0)
    die (EXIT_FAILURE, 0, _("invalid field number: %s"), quote (str));

  result = val - 1;

  return result;
}

/* Convert a single field specifier string, S, to a *FILE_INDEX, *FIELD_INDEX
   pair.  In S, the field index string is 1-based; *FIELD_INDEX is zero-based.
   If S is valid, return true.  Otherwise, give a diagnostic and exit.  */

static void
decode_field_spec (const char *s, int *file_index, size_t *field_index)
{
  /* The first character must be 0, 1, or 2.  */
  switch (s[0])
    {
    case '0':
      if (s[1])
        {
          /* '0' must be all alone -- no '.FIELD'.  */
          die (EXIT_FAILURE, 0, _("invalid field specifier: %s"), quote (s));
        }
      *file_index = 0;
      *field_index = 0;
      break;

    case '1':
    case '2':
      if (s[1] != '.')
        die (EXIT_FAILURE, 0, _("invalid field specifier: %s"), quote (s));
      *file_index = s[0] - '0';
      *field_index = string_to_join_field (s + 2);
      break;

    default:
      die (EXIT_FAILURE, 0,
           _("invalid file number in field spec: %s"), quote (s));

      /* Tell gcc -W -Wall that we can't get beyond this point.
         This avoids a warning (otherwise legit) that the caller's copies
         of *file_index and *field_index might be used uninitialized.  */
      abort ();

      break;
    }
}

/* Add the comma or blank separated field spec(s) in STR to 'outlist'.  */

static void
add_field_list (char *str)
{
  char *p = str;

  do
    {
      int file_index;
      size_t field_index;
      char const *spec_item = p;

      p = strpbrk (p, ", \t");
      if (p)
        *p++ = '\0';
      decode_field_spec (spec_item, &file_index, &field_index);
      add_field (file_index, field_index);
    }
  while (p);
}

/* Set the join field *VAR to VAL, but report an error if *VAR is set
   more than once to incompatible values.  */

static void
set_join_field (size_t *var, size_t val)
{
  if (*var != SIZE_MAX && *var != val)
    {
      unsigned long int var1 = *var + 1;
      unsigned long int val1 = val + 1;
      die (EXIT_FAILURE, 0,
           _("incompatible join fields %lu, %lu"), var1, val1);
    }
  *var = val;
}

/* Status of command-line arguments.  */

enum operand_status
  {
    /* This argument must be an operand, i.e., one of the files to be
       joined.  */
    MUST_BE_OPERAND,

    /* This might be the argument of the preceding -j1 or -j2 option,
       or it might be an operand.  */
    MIGHT_BE_J1_ARG,
    MIGHT_BE_J2_ARG,

    /* This might be the argument of the preceding -o option, or it might be
       an operand.  */
    MIGHT_BE_O_ARG
  };

/* Add NAME to the array of input file NAMES with operand statuses
   OPERAND_STATUS; currently there are NFILES names in the list.  */

static void
add_file_name (char *name, char *names[2],
               int operand_status[2], int joption_count[2], int *nfiles,
               int *prev_optc_status, int *optc_status)
{
  int n = *nfiles;

  if (n == 2)
    {
      bool op0 = (operand_status[0] == MUST_BE_OPERAND);
      char *arg = names[op0];
      switch (operand_status[op0])
        {
        case MUST_BE_OPERAND:
          error (0, 0, _("extra operand %s"), quoteaf (name));
          usage (EXIT_FAILURE);

        case MIGHT_BE_J1_ARG:
          joption_count[0]--;
          set_join_field (&join_field_1, string_to_join_field (arg));
          break;

        case MIGHT_BE_J2_ARG:
          joption_count[1]--;
          set_join_field (&join_field_2, string_to_join_field (arg));
          break;

        case MIGHT_BE_O_ARG:
          add_field_list (arg);
          break;
        }
      if (!op0)
        {
          operand_status[0] = operand_status[1];
          names[0] = names[1];
        }
      n = 1;
    }

  operand_status[n] = *prev_optc_status;
  names[n] = name;
  *nfiles = n + 1;
  if (*prev_optc_status == MIGHT_BE_O_ARG)
    *optc_status = MIGHT_BE_O_ARG;
}

int
main (int argc, char **argv)
{
  int optc_status;
  int prev_optc_status = MUST_BE_OPERAND;
  int operand_status[2];
  int joption_count[2] = { 0, 0 };
  FILE *fp1, *fp2;
  int optc;
  int nfiles = 0;
  int i;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);
  hard_LC_COLLATE = hard_locale (LC_COLLATE);

  atexit (close_stdout);
  atexit (free_spareline);

  print_pairables = true;
  seen_unpairable = false;
  issued_disorder_warning[0] = issued_disorder_warning[1] = false;
  check_input_order = CHECK_ORDER_DEFAULT;

  while ((optc = getopt_long (argc, argv, "-a:e:i1:2:j:o:t:v:z",
                              longopts, NULL))
         != -1)
    {
      optc_status = MUST_BE_OPERAND;

      switch (optc)
        {
        case 'v':
            print_pairables = false;
            /* Fall through.  */

        case 'a':
          {
            unsigned long int val;
            if (xstrtoul (optarg, NULL, 10, &val, "") != LONGINT_OK
                || (val != 1 && val != 2))
              die (EXIT_FAILURE, 0,
                   _("invalid field number: %s"), quote (optarg));
            if (val == 1)
              print_unpairables_1 = true;
            else
              print_unpairables_2 = true;
          }
          break;

        case 'e':
          if (empty_filler && ! STREQ (empty_filler, optarg))
            die (EXIT_FAILURE, 0,
                 _("conflicting empty-field replacement strings"));
          empty_filler = optarg;
          break;

        case 'i':
          ignore_case = true;
          break;

        case '1':
          set_join_field (&join_field_1, string_to_join_field (optarg));
          break;

        case '2':
          set_join_field (&join_field_2, string_to_join_field (optarg));
          break;

        case 'j':
          if ((optarg[0] == '1' || optarg[0] == '2') && !optarg[1]
              && optarg == argv[optind - 1] + 2)
            {
              /* The argument was either "-j1" or "-j2".  */
              bool is_j2 = (optarg[0] == '2');
              joption_count[is_j2]++;
              optc_status = MIGHT_BE_J1_ARG + is_j2;
            }
          else
            {
              set_join_field (&join_field_1, string_to_join_field (optarg));
              set_join_field (&join_field_2, join_field_1);
            }
          break;

        case 'o':
          if (STREQ (optarg, "auto"))
            autoformat = true;
          else
            {
              add_field_list (optarg);
              optc_status = MIGHT_BE_O_ARG;
            }
          break;

        case 't':
          {
            unsigned char newtab = optarg[0];
            if (! newtab)
              newtab = '\n'; /* '' => process the whole line.  */
            else if (optarg[1])
              {
                if (STREQ (optarg, "\\0"))
                  newtab = '\0';
                else
                  die (EXIT_FAILURE, 0, _("multi-character tab %s"),
                       quote (optarg));
              }
            if (0 <= tab && tab != newtab)
              die (EXIT_FAILURE, 0, _("incompatible tabs"));
            tab = newtab;
          }
          break;

        case 'z':
          eolchar = 0;
          break;

        case NOCHECK_ORDER_OPTION:
          check_input_order = CHECK_ORDER_DISABLED;
          break;

        case CHECK_ORDER_OPTION:
          check_input_order = CHECK_ORDER_ENABLED;
          break;

        case 1:		/* Non-option argument.  */
          add_file_name (optarg, g_names, operand_status, joption_count,
                         &nfiles, &prev_optc_status, &optc_status);
          break;

        case HEADER_LINE_OPTION:
          join_header_lines = true;
          break;

        case_GETOPT_HELP_CHAR;

        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);

        default:
          usage (EXIT_FAILURE);
        }

      prev_optc_status = optc_status;
    }

  /* Process any operands after "--".  */
  prev_optc_status = MUST_BE_OPERAND;
  while (optind < argc)
    add_file_name (argv[optind++], g_names, operand_status, joption_count,
                   &nfiles, &prev_optc_status, &optc_status);

  if (nfiles != 2)
    {
      if (nfiles == 0)
        error (0, 0, _("missing operand"));
      else
        error (0, 0, _("missing operand after %s"), quote (argv[argc - 1]));
      usage (EXIT_FAILURE);
    }

  /* If "-j1" was specified and it turns out not to have had an argument,
     treat it as "-j 1".  Likewise for -j2.  */
  for (i = 0; i < 2; i++)
    if (joption_count[i] != 0)
      {
        set_join_field (&join_field_1, i);
        set_join_field (&join_field_2, i);
      }

  if (join_field_1 == SIZE_MAX)
    join_field_1 = 0;
  if (join_field_2 == SIZE_MAX)
    join_field_2 = 0;

  fp1 = STREQ (g_names[0], "-") ? stdin : fopen (g_names[0], "r");
  if (!fp1)
    die (EXIT_FAILURE, errno, "%s", quotef (g_names[0]));
  fp2 = STREQ (g_names[1], "-") ? stdin : fopen (g_names[1], "r");
  if (!fp2)
    die (EXIT_FAILURE, errno, "%s", quotef (g_names[1]));
  if (fp1 == fp2)
    die (EXIT_FAILURE, errno, _("both files cannot be standard input"));
  join (fp1, fp2);

  if (fclose (fp1) != 0)
    die (EXIT_FAILURE, errno, "%s", quotef (g_names[0]));
  if (fclose (fp2) != 0)
    die (EXIT_FAILURE, errno, "%s", quotef (g_names[1]));

  if (issued_disorder_warning[0] || issued_disorder_warning[1])
    return EXIT_FAILURE;
  else
    return EXIT_SUCCESS;
}
