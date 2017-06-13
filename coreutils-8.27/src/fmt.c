/* GNU fmt -- simple text formatter.
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

/* Written by Ross Paterson <rap@doc.ic.ac.uk>.  */

#include <config.h>
#include <stdio.h>
#include <sys/types.h>
#include <getopt.h>
#include <assert.h>

/* Redefine.  Otherwise, systems (Unicos for one) with headers that define
   it to be a type get syntax errors for the variable declaration below.  */
#define word unused_word_type

#include "system.h"
#include "error.h"
#include "fadvise.h"
#include "xdectoint.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "fmt"

#define AUTHORS proper_name ("Ross Paterson")

/* The following parameters represent the program's idea of what is
   "best".  Adjust to taste, subject to the caveats given.  */

/* Default longest permitted line length (max_width).  */
#define WIDTH	75

/* Prefer lines to be LEEWAY % shorter than the maximum width, giving
   room for optimization.  */
#define LEEWAY	7

/* The default secondary indent of tagged paragraph used for unindented
   one-line paragraphs not preceded by any multi-line paragraphs.  */
#define DEF_INDENT 3

/* Costs and bonuses are expressed as the equivalent departure from the
   optimal line length, multiplied by 10.  e.g. assigning something a
   cost of 50 means that it is as bad as a line 5 characters too short
   or too long.  The definition of SHORT_COST(n) should not be changed.
   However, EQUIV(n) may need tuning.  */

/* FIXME: "fmt" misbehaves given large inputs or options.  One
   possible workaround for part of the problem is to change COST to be
   a floating-point type.  There are other problems besides COST,
   though; see MAXWORDS below.  */

typedef long int COST;

#define MAXCOST	TYPE_MAXIMUM (COST)

#define SQR(n)		((n) * (n))
#define EQUIV(n)	SQR ((COST) (n))

/* Cost of a filled line n chars longer or shorter than goal_width.  */
#define SHORT_COST(n)	EQUIV ((n) * 10)

/* Cost of the difference between adjacent filled lines.  */
#define RAGGED_COST(n)	(SHORT_COST (n) / 2)

/* Basic cost per line.  */
#define LINE_COST	EQUIV (70)

/* Cost of breaking a line after the first word of a sentence, where
   the length of the word is N.  */
#define WIDOW_COST(n)	(EQUIV (200) / ((n) + 2))

/* Cost of breaking a line before the last word of a sentence, where
   the length of the word is N.  */
#define ORPHAN_COST(n)	(EQUIV (150) / ((n) + 2))

/* Bonus for breaking a line at the end of a sentence.  */
#define SENTENCE_BONUS	EQUIV (50)

/* Cost of breaking a line after a period not marking end of a sentence.
   With the definition of sentence we are using (borrowed from emacs, see
   get_line()) such a break would then look like a sentence break.  Hence
   we assign a very high cost -- it should be avoided unless things are
   really bad.  */
#define NOBREAK_COST	EQUIV (600)

/* Bonus for breaking a line before open parenthesis.  */
#define PAREN_BONUS	EQUIV (40)

/* Bonus for breaking a line after other punctuation.  */
#define PUNCT_BONUS	EQUIV(40)

/* Credit for breaking a long paragraph one line later.  */
#define LINE_CREDIT	EQUIV(3)

/* Size of paragraph buffer, in words and characters.  Longer paragraphs
   are handled neatly (cf. flush_paragraph()), so long as these values
   are considerably greater than required by the width.  These values
   cannot be extended indefinitely: doing so would run into size limits
   and/or cause more overflows in cost calculations.  FIXME: Remove these
   arbitrary limits.  */

#define MAXWORDS	1000
#define MAXCHARS	5000

/* Extra ctype(3)-style macros.  */

#define isopen(c)	(strchr ("(['`\"", c) != NULL)
#define isclose(c)	(strchr (")]'\"", c) != NULL)
#define isperiod(c)	(strchr (".?!", c) != NULL)

/* Size of a tab stop, for expansion on input and re-introduction on
   output.  */
#define TABWIDTH	8

/* Word descriptor structure.  */

typedef struct Word WORD;

struct Word
  {

    /* Static attributes determined during input.  */

    const char *text;		/* the text of the word */
    int length;			/* length of this word */
    int space;			/* the size of the following space */
    unsigned int paren:1;	/* starts with open paren */
    unsigned int period:1;	/* ends in [.?!])* */
    unsigned int punct:1;	/* ends in punctuation */
    unsigned int final:1;	/* end of sentence */

    /* The remaining fields are computed during the optimization.  */

    int line_length;		/* length of the best line starting here */
    COST best_cost;		/* cost of best paragraph starting here */
    WORD *next_break;		/* break which achieves best_cost */
  };

/* Forward declarations.  */

static void set_prefix (char *p);
static void fmt (FILE *f);
static bool get_paragraph (FILE *f);
static int get_line (FILE *f, int c);
static int get_prefix (FILE *f);
static int get_space (FILE *f, int c);
static int copy_rest (FILE *f, int c);
static bool same_para (int c);
static void flush_paragraph (void);
static void fmt_paragraph (void);
static void check_punctuation (WORD *w);
static COST base_cost (WORD *this);
static COST line_cost (WORD *next, int len);
static void put_paragraph (WORD *finish);
static void put_line (WORD *w, int indent);
static void put_word (WORD *w);
static void put_space (int space);

/* Option values.  */

/* If true, first 2 lines may have different indent (default false).  */
static bool crown;

/* If true, first 2 lines _must_ have different indent (default false).  */
static bool tagged;

/* If true, each line is a paragraph on its own (default false).  */
static bool split;

/* If true, don't preserve inter-word spacing (default false).  */
static bool uniform;

/* Prefix minus leading and trailing spaces (default "").  */
static const char *prefix;

/* User-supplied maximum line width (default WIDTH).  The only output
   lines longer than this will each comprise a single word.  */
static int max_width;

/* Values derived from the option values.  */

/* The length of prefix minus leading space.  */
static int prefix_full_length;

/* The length of the leading space trimmed from the prefix.  */
static int prefix_lead_space;

/* The length of prefix minus leading and trailing space.  */
static int prefix_length;

/* The preferred width of text lines, set to LEEWAY % less than max_width.  */
static int goal_width;

/* Dynamic variables.  */

/* Start column of the character most recently read from the input file.  */
static int in_column;

/* Start column of the next character to be written to stdout.  */
static int out_column;

/* Space for the paragraph text -- longer paragraphs are handled neatly
   (cf. flush_paragraph()).  */
static char parabuf[MAXCHARS];

/* A pointer into parabuf, indicating the first unused character position.  */
static char *wptr;

/* The words of a paragraph -- longer paragraphs are handled neatly
   (cf. flush_paragraph()).  */
static WORD word[MAXWORDS];

/* A pointer into the above word array, indicating the first position
   after the last complete word.  Sometimes it will point at an incomplete
   word.  */
static WORD *word_limit;

/* If true, current input file contains tab characters, and so tabs can be
   used for white space on output.  */
static bool tabs;

/* Space before trimmed prefix on each line of the current paragraph.  */
static int prefix_indent;

/* Indentation of the first line of the current paragraph.  */
static int first_indent;

/* Indentation of other lines of the current paragraph */
static int other_indent;

/* To detect the end of a paragraph, we need to look ahead to the first
   non-blank character after the prefix on the next line, or the first
   character on the following line that failed to match the prefix.
   We can reconstruct the lookahead from that character (next_char), its
   position on the line (in_column) and the amount of space before the
   prefix (next_prefix_indent).  See get_paragraph() and copy_rest().  */

/* The last character read from the input file.  */
static int next_char;

/* The space before the trimmed prefix (or part of it) on the next line
   after the current paragraph.  */
static int next_prefix_indent;

/* If nonzero, the length of the last line output in the current
   paragraph, used to charge for raggedness at the split point for long
   paragraphs chosen by fmt_paragraph().  */
static int last_line_length;

void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("Usage: %s [-WIDTH] [OPTION]... [FILE]...\n"), program_name);
      fputs (_("\
Reformat each paragraph in the FILE(s), writing to standard output.\n\
The option -WIDTH is an abbreviated form of --width=DIGITS.\n\
"), stdout);

      emit_stdin_note ();
      emit_mandatory_arg_note ();

      fputs (_("\
  -c, --crown-margin        preserve indentation of first two lines\n\
  -p, --prefix=STRING       reformat only lines beginning with STRING,\n\
                              reattaching the prefix to reformatted lines\n\
  -s, --split-only          split long lines, but do not refill\n\
"),
             stdout);
      /* Tell xgettext that the "% o" below is not a printf-style
         format string:  xgettext:no-c-format */
      fputs (_("\
  -t, --tagged-paragraph    indentation of first line different from second\n\
  -u, --uniform-spacing     one space between words, two after sentences\n\
  -w, --width=WIDTH         maximum line width (default of 75 columns)\n\
  -g, --goal=WIDTH          goal width (default of 93% of width)\n\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

/* Decode options and launch execution.  */

static struct option const long_options[] =
{
  {"crown-margin", no_argument, NULL, 'c'},
  {"prefix", required_argument, NULL, 'p'},
  {"split-only", no_argument, NULL, 's'},
  {"tagged-paragraph", no_argument, NULL, 't'},
  {"uniform-spacing", no_argument, NULL, 'u'},
  {"width", required_argument, NULL, 'w'},
  {"goal", required_argument, NULL, 'g'},
  {GETOPT_HELP_OPTION_DECL},
  {GETOPT_VERSION_OPTION_DECL},
  {NULL, 0, NULL, 0},
};

int
main (int argc, char **argv)
{
  int optchar;
  bool ok = true;
  char const *max_width_option = NULL;
  char const *goal_width_option = NULL;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  crown = tagged = split = uniform = false;
  max_width = WIDTH;
  prefix = "";
  prefix_length = prefix_lead_space = prefix_full_length = 0;

  if (argc > 1 && argv[1][0] == '-' && ISDIGIT (argv[1][1]))
    {
      /* Old option syntax; a dash followed by one or more digits.  */
      max_width_option = argv[1] + 1;

      /* Make the option we just parsed invisible to getopt.  */
      argv[1] = argv[0];
      argv++;
      argc--;
    }

  while ((optchar = getopt_long (argc, argv, "0123456789cstuw:p:g:",
                                 long_options, NULL))
         != -1)
    switch (optchar)
      {
      default:
        if (ISDIGIT (optchar))
          error (0, 0, _("invalid option -- %c; -WIDTH is recognized\
 only when it is the first\noption; use -w N instead"),
                 optchar);
        usage (EXIT_FAILURE);

      case 'c':
        crown = true;
        break;

      case 's':
        split = true;
        break;

      case 't':
        tagged = true;
        break;

      case 'u':
        uniform = true;
        break;

      case 'w':
        max_width_option = optarg;
        break;

      case 'g':
        goal_width_option = optarg;
        break;

      case 'p':
        set_prefix (optarg);
        break;

      case_GETOPT_HELP_CHAR;

      case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);

      }

  if (max_width_option)
    {
      /* Limit max_width to MAXCHARS / 2; otherwise, the resulting
         output can be quite ugly.  */
      max_width = xdectoumax (max_width_option, 0, MAXCHARS / 2, "",
                              _("invalid width"), 0);
    }

  if (goal_width_option)
    {
      /* Limit goal_width to max_width.  */
      goal_width = xdectoumax (goal_width_option, 0, max_width, "",
                               _("invalid width"), 0);
      if (max_width_option == NULL)
        max_width = goal_width + 10;
    }
  else
    {
      goal_width = max_width * (2 * (100 - LEEWAY) + 1) / 200;
    }

  if (optind == argc)
    fmt (stdin);
  else
    {
      for (; optind < argc; optind++)
        {
          char *file = argv[optind];
          if (STREQ (file, "-"))
            fmt (stdin);
          else
            {
              FILE *in_stream;
              in_stream = fopen (file, "r");
              if (in_stream != NULL)
                {
                  fmt (in_stream);
                  if (fclose (in_stream) == EOF)
                    {
                      error (0, errno, "%s", quotef (file));
                      ok = false;
                    }
                }
              else
                {
                  error (0, errno, _("cannot open %s for reading"),
                         quoteaf (file));
                  ok = false;
                }
            }
        }
    }

  return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}

/* Trim space from the front and back of the string P, yielding the prefix,
   and record the lengths of the prefix and the space trimmed.  */

static void
set_prefix (char *p)
{
  char *s;

  prefix_lead_space = 0;
  while (*p == ' ')
    {
      prefix_lead_space++;
      p++;
    }
  prefix = p;
  prefix_full_length = strlen (p);
  s = p + prefix_full_length;
  while (s > p && s[-1] == ' ')
    s--;
  *s = '\0';
  prefix_length = s - p;
}

/* read file F and send formatted output to stdout.  */

static void
fmt (FILE *f)
{
  fadvise (f, FADVISE_SEQUENTIAL);
  tabs = false;
  other_indent = 0;
  next_char = get_prefix (f);
  while (get_paragraph (f))
    {
      fmt_paragraph ();
      put_paragraph (word_limit);
    }
}

/* Set the global variable 'other_indent' according to SAME_PARAGRAPH
   and other global variables.  */

static void
set_other_indent (bool same_paragraph)
{
  if (split)
    other_indent = first_indent;
  else if (crown)
    {
      other_indent = (same_paragraph ? in_column : first_indent);
    }
  else if (tagged)
    {
      if (same_paragraph && in_column != first_indent)
        {
          other_indent = in_column;
        }

      /* Only one line: use the secondary indent from last time if it
         splits, or 0 if there have been no multi-line paragraphs in the
         input so far.  But if these rules make the two indents the same,
         pick a new secondary indent.  */

      else if (other_indent == first_indent)
        other_indent = first_indent == 0 ? DEF_INDENT : 0;
    }
  else
    {
      other_indent = first_indent;
    }
}

/* Read a paragraph from input file F.  A paragraph consists of a
   maximal number of non-blank (excluding any prefix) lines subject to:
   * In split mode, a paragraph is a single non-blank line.
   * In crown mode, the second and subsequent lines must have the
   same indentation, but possibly different from the indent of the
   first line.
   * Tagged mode is similar, but the first and second lines must have
   different indentations.
   * Otherwise, all lines of a paragraph must have the same indent.
   If a prefix is in effect, it must be present at the same indent for
   each line in the paragraph.

   Return false if end-of-file was encountered before the start of a
   paragraph, else true.  */

static bool
get_paragraph (FILE *f)
{
  int c;

  last_line_length = 0;
  c = next_char;

  /* Scan (and copy) blank lines, and lines not introduced by the prefix.  */

  while (c == '\n' || c == EOF
         || next_prefix_indent < prefix_lead_space
         || in_column < next_prefix_indent + prefix_full_length)
    {
      c = copy_rest (f, c);
      if (c == EOF)
        {
          next_char = EOF;
          return false;
        }
      putchar ('\n');
      c = get_prefix (f);
    }

  /* Got a suitable first line for a paragraph.  */

  prefix_indent = next_prefix_indent;
  first_indent = in_column;
  wptr = parabuf;
  word_limit = word;
  c = get_line (f, c);
  set_other_indent (same_para (c));

  /* Read rest of paragraph (unless split is specified).  */

  if (split)
    {
      /* empty */
    }
  else if (crown)
    {
      if (same_para (c))
        {
          do
            {			/* for each line till the end of the para */
              c = get_line (f, c);
            }
          while (same_para (c) && in_column == other_indent);
        }
    }
  else if (tagged)
    {
      if (same_para (c) && in_column != first_indent)
        {
          do
            {			/* for each line till the end of the para */
              c = get_line (f, c);
            }
          while (same_para (c) && in_column == other_indent);
        }
    }
  else
    {
      while (same_para (c) && in_column == other_indent)
        c = get_line (f, c);
    }

  /* Tell static analysis tools that using word_limit[-1] is ok.
     word_limit is guaranteed to have been incremented by get_line.  */
  assert (word < word_limit);

  (word_limit - 1)->period = (word_limit - 1)->final = true;
  next_char = c;
  return true;
}

/* Copy to the output a line that failed to match the prefix, or that
   was blank after the prefix.  In the former case, C is the character
   that failed to match the prefix.  In the latter, C is \n or EOF.
   Return the character (\n or EOF) ending the line.  */

static int
copy_rest (FILE *f, int c)
{
  const char *s;

  out_column = 0;
  if (in_column > next_prefix_indent || (c != '\n' && c != EOF))
    {
      put_space (next_prefix_indent);
      for (s = prefix; out_column != in_column && *s; out_column++)
        putchar (*s++);
      if (c != EOF && c != '\n')
        put_space (in_column - out_column);
      if (c == EOF && in_column >= next_prefix_indent + prefix_length)
        putchar ('\n');
    }
  while (c != '\n' && c != EOF)
    {
      putchar (c);
      c = getc (f);
    }
  return c;
}

/* Return true if a line whose first non-blank character after the
   prefix (if any) is C could belong to the current paragraph,
   otherwise false.  */

static bool
same_para (int c)
{
  return (next_prefix_indent == prefix_indent
          && in_column >= next_prefix_indent + prefix_full_length
          && c != '\n' && c != EOF);
}

/* Read a line from input file F, given first non-blank character C
   after the prefix, and the following indent, and break it into words.
   A word is a maximal non-empty string of non-white characters.  A word
   ending in [.?!]["')\]]* and followed by end-of-line or at least two
   spaces ends a sentence, as in emacs.

   Return the first non-blank character of the next line.  */

static int
get_line (FILE *f, int c)
{
  int start;
  char *end_of_parabuf;
  WORD *end_of_word;

  end_of_parabuf = &parabuf[MAXCHARS];
  end_of_word = &word[MAXWORDS - 2];

  do
    {				/* for each word in a line */

      /* Scan word.  */

      word_limit->text = wptr;
      do
        {
          if (wptr == end_of_parabuf)
            {
              set_other_indent (true);
              flush_paragraph ();
            }
          *wptr++ = c;
          c = getc (f);
        }
      while (c != EOF && !isspace (c));
      in_column += word_limit->length = wptr - word_limit->text;
      check_punctuation (word_limit);

      /* Scan inter-word space.  */

      start = in_column;
      c = get_space (f, c);
      word_limit->space = in_column - start;
      word_limit->final = (c == EOF
                           || (word_limit->period
                               && (c == '\n' || word_limit->space > 1)));
      if (c == '\n' || c == EOF || uniform)
        word_limit->space = word_limit->final ? 2 : 1;
      if (word_limit == end_of_word)
        {
          set_other_indent (true);
          flush_paragraph ();
        }
      word_limit++;
    }
  while (c != '\n' && c != EOF);
  return get_prefix (f);
}

/* Read a prefix from input file F.  Return either first non-matching
   character, or first non-blank character after the prefix.  */

static int
get_prefix (FILE *f)
{
  int c;

  in_column = 0;
  c = get_space (f, getc (f));
  if (prefix_length == 0)
    next_prefix_indent = prefix_lead_space < in_column ?
      prefix_lead_space : in_column;
  else
    {
      const char *p;
      next_prefix_indent = in_column;
      for (p = prefix; *p != '\0'; p++)
        {
          unsigned char pc = *p;
          if (c != pc)
            return c;
          in_column++;
          c = getc (f);
        }
      c = get_space (f, c);
    }
  return c;
}

/* Read blank characters from input file F, starting with C, and keeping
   in_column up-to-date.  Return first non-blank character.  */

static int
get_space (FILE *f, int c)
{
  while (true)
    {
      if (c == ' ')
        in_column++;
      else if (c == '\t')
        {
          tabs = true;
          in_column = (in_column / TABWIDTH + 1) * TABWIDTH;
        }
      else
        return c;
      c = getc (f);
    }
}

/* Set extra fields in word W describing any attached punctuation.  */

static void
check_punctuation (WORD *w)
{
  char const *start = w->text;
  char const *finish = start + (w->length - 1);
  unsigned char fin = *finish;

  w->paren = isopen (*start);
  w->punct = !! ispunct (fin);
  while (start < finish && isclose (*finish))
    finish--;
  w->period = isperiod (*finish);
}

/* Flush part of the paragraph to make room.  This function is called on
   hitting the limit on the number of words or characters.  */

static void
flush_paragraph (void)
{
  WORD *split_point;
  WORD *w;
  int shift;
  COST best_break;

  /* In the special case where it's all one word, just flush it.  */

  if (word_limit == word)
    {
      fwrite (parabuf, sizeof *parabuf, wptr - parabuf, stdout);
      wptr = parabuf;
      return;
    }

  /* Otherwise:
     - format what you have so far as a paragraph,
     - find a low-cost line break near the end,
     - output to there,
     - make that the start of the paragraph.  */

  fmt_paragraph ();

  /* Choose a good split point.  */

  split_point = word_limit;
  best_break = MAXCOST;
  for (w = word->next_break; w != word_limit; w = w->next_break)
    {
      if (w->best_cost - w->next_break->best_cost < best_break)
        {
          split_point = w;
          best_break = w->best_cost - w->next_break->best_cost;
        }
      if (best_break <= MAXCOST - LINE_CREDIT)
        best_break += LINE_CREDIT;
    }
  put_paragraph (split_point);

  /* Copy text of words down to start of parabuf -- we use memmove because
     the source and target may overlap.  */

  memmove (parabuf, split_point->text, wptr - split_point->text);
  shift = split_point->text - parabuf;
  wptr -= shift;

  /* Adjust text pointers.  */

  for (w = split_point; w <= word_limit; w++)
    w->text -= shift;

  /* Copy words from split_point down to word -- we use memmove because
     the source and target may overlap.  */

  memmove (word, split_point, (word_limit - split_point + 1) * sizeof *word);
  word_limit -= split_point - word;
}

/* Compute the optimal formatting for the whole paragraph by computing
   and remembering the optimal formatting for each suffix from the empty
   one to the whole paragraph.  */

static void
fmt_paragraph (void)
{
  WORD *start, *w;
  int len;
  COST wcost, best;
  int saved_length;

  word_limit->best_cost = 0;
  saved_length = word_limit->length;
  word_limit->length = max_width;	/* sentinel */

  for (start = word_limit - 1; start >= word; start--)
    {
      best = MAXCOST;
      len = start == word ? first_indent : other_indent;

      /* At least one word, however long, in the line.  */

      w = start;
      len += w->length;
      do
        {
          w++;

          /* Consider breaking before w.  */

          wcost = line_cost (w, len) + w->best_cost;
          if (start == word && last_line_length > 0)
            wcost += RAGGED_COST (len - last_line_length);
          if (wcost < best)
            {
              best = wcost;
              start->next_break = w;
              start->line_length = len;
            }

          /* This is a kludge to keep us from computing 'len' as the
             sum of the sentinel length and some non-zero number.
             Since the sentinel w->length may be INT_MAX, adding
             to that would give a negative result.  */
          if (w == word_limit)
            break;

          len += (w - 1)->space + w->length;	/* w > start >= word */
        }
      while (len < max_width);
      start->best_cost = best + base_cost (start);
    }

  word_limit->length = saved_length;
}

/* Return the constant component of the cost of breaking before the
   word THIS.  */

static COST
base_cost (WORD *this)
{
  COST cost;

  cost = LINE_COST;

  if (this > word)
    {
      if ((this - 1)->period)
        {
          if ((this - 1)->final)
            cost -= SENTENCE_BONUS;
          else
            cost += NOBREAK_COST;
        }
      else if ((this - 1)->punct)
        cost -= PUNCT_BONUS;
      else if (this > word + 1 && (this - 2)->final)
        cost += WIDOW_COST ((this - 1)->length);
    }

  if (this->paren)
    cost -= PAREN_BONUS;
  else if (this->final)
    cost += ORPHAN_COST (this->length);

  return cost;
}

/* Return the component of the cost of breaking before word NEXT that
   depends on LEN, the length of the line beginning there.  */

static COST
line_cost (WORD *next, int len)
{
  int n;
  COST cost;

  if (next == word_limit)
    return 0;
  n = goal_width - len;
  cost = SHORT_COST (n);
  if (next->next_break != word_limit)
    {
      n = len - next->line_length;
      cost += RAGGED_COST (n);
    }
  return cost;
}

/* Output to stdout a paragraph from word up to (but not including)
   FINISH, which must be in the next_break chain from word.  */

static void
put_paragraph (WORD *finish)
{
  WORD *w;

  put_line (word, first_indent);
  for (w = word->next_break; w != finish; w = w->next_break)
    put_line (w, other_indent);
}

/* Output to stdout the line beginning with word W, beginning in column
   INDENT, including the prefix (if any).  */

static void
put_line (WORD *w, int indent)
{
  WORD *endline;

  out_column = 0;
  put_space (prefix_indent);
  fputs (prefix, stdout);
  out_column += prefix_length;
  put_space (indent - out_column);

  endline = w->next_break - 1;
  for (; w != endline; w++)
    {
      put_word (w);
      put_space (w->space);
    }
  put_word (w);
  last_line_length = out_column;
  putchar ('\n');
}

/* Output to stdout the word W.  */

static void
put_word (WORD *w)
{
  const char *s;
  int n;

  s = w->text;
  for (n = w->length; n != 0; n--)
    putchar (*s++);
  out_column += w->length;
}

/* Output to stdout SPACE spaces, or equivalent tabs.  */

static void
put_space (int space)
{
  int space_target, tab_target;

  space_target = out_column + space;
  if (tabs)
    {
      tab_target = space_target / TABWIDTH * TABWIDTH;
      if (out_column + 1 < tab_target)
        while (out_column < tab_target)
          {
            putchar ('\t');
            out_column = (out_column / TABWIDTH + 1) * TABWIDTH;
          }
    }
  while (out_column < space_target)
    {
      putchar (' ');
      out_column++;
    }
}
