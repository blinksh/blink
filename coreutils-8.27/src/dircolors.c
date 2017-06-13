/* dircolors - output commands to set the LS_COLOR environment variable
   Copyright (C) 1996-2017 Free Software Foundation, Inc.
   Copyright (C) 1994, 1995, 1997, 1998, 1999, 2000 H. Peter Anvin

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

#include <config.h>

#include <sys/types.h>
#include <fnmatch.h>
#include <getopt.h>

#include "system.h"
#include "dircolors.h"
#include "c-strcase.h"
#include "die.h"
#include "error.h"
#include "obstack.h"
#include "quote.h"
#include "stdio--.h"
#include "xstrndup.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "dircolors"

#define AUTHORS proper_name ("H. Peter Anvin")

#define obstack_chunk_alloc malloc
#define obstack_chunk_free free

enum Shell_syntax
{
  SHELL_SYNTAX_BOURNE,
  SHELL_SYNTAX_C,
  SHELL_SYNTAX_UNKNOWN
};

#define APPEND_CHAR(C) obstack_1grow (&lsc_obstack, C)
#define APPEND_TWO_CHAR_STRING(S)					\
  do									\
    {									\
      APPEND_CHAR (S[0]);						\
      APPEND_CHAR (S[1]);						\
    }									\
  while (0)

/* Accumulate in this obstack the value for the LS_COLORS environment
   variable.  */
static struct obstack lsc_obstack;

static const char *const slack_codes[] =
{
  "NORMAL", "NORM", "FILE", "RESET", "DIR", "LNK", "LINK",
  "SYMLINK", "ORPHAN", "MISSING", "FIFO", "PIPE", "SOCK", "BLK", "BLOCK",
  "CHR", "CHAR", "DOOR", "EXEC", "LEFT", "LEFTCODE", "RIGHT", "RIGHTCODE",
  "END", "ENDCODE", "SUID", "SETUID", "SGID", "SETGID", "STICKY",
  "OTHER_WRITABLE", "OWR", "STICKY_OTHER_WRITABLE", "OWT", "CAPABILITY",
  "MULTIHARDLINK", "CLRTOEOL", NULL
};

static const char *const ls_codes[] =
{
  "no", "no", "fi", "rs", "di", "ln", "ln", "ln", "or", "mi", "pi", "pi",
  "so", "bd", "bd", "cd", "cd", "do", "ex", "lc", "lc", "rc", "rc", "ec", "ec",
  "su", "su", "sg", "sg", "st", "ow", "ow", "tw", "tw", "ca", "mh", "cl", NULL
};
verify (ARRAY_CARDINALITY (slack_codes) == ARRAY_CARDINALITY (ls_codes));

static struct option const long_options[] =
  {
    {"bourne-shell", no_argument, NULL, 'b'},
    {"sh", no_argument, NULL, 'b'},
    {"csh", no_argument, NULL, 'c'},
    {"c-shell", no_argument, NULL, 'c'},
    {"print-database", no_argument, NULL, 'p'},
    {GETOPT_HELP_OPTION_DECL},
    {GETOPT_VERSION_OPTION_DECL},
    {NULL, 0, NULL, 0}
  };

void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("Usage: %s [OPTION]... [FILE]\n"), program_name);
      fputs (_("\
Output commands to set the LS_COLORS environment variable.\n\
\n\
Determine format of output:\n\
  -b, --sh, --bourne-shell    output Bourne shell code to set LS_COLORS\n\
  -c, --csh, --c-shell        output C shell code to set LS_COLORS\n\
  -p, --print-database        output defaults\n\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      fputs (_("\
\n\
If FILE is specified, read it to determine which colors to use for which\n\
file types and extensions.  Otherwise, a precompiled database is used.\n\
For details on the format of these files, run 'dircolors --print-database'.\n\
"), stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }

  exit (status);
}

/* If the SHELL environment variable is set to 'csh' or 'tcsh,'
   assume C shell.  Else Bourne shell.  */

static enum Shell_syntax
guess_shell_syntax (void)
{
  char *shell;

  shell = getenv ("SHELL");
  if (shell == NULL || *shell == '\0')
    return SHELL_SYNTAX_UNKNOWN;

  shell = last_component (shell);

  if (STREQ (shell, "csh") || STREQ (shell, "tcsh"))
    return SHELL_SYNTAX_C;

  return SHELL_SYNTAX_BOURNE;
}

static void
parse_line (char const *line, char **keyword, char **arg)
{
  char const *p;
  char const *keyword_start;
  char const *arg_start;

  *keyword = NULL;
  *arg = NULL;

  for (p = line; isspace (to_uchar (*p)); ++p)
    continue;

  /* Ignore blank lines and shell-style comments.  */
  if (*p == '\0' || *p == '#')
    return;

  keyword_start = p;

  while (!isspace (to_uchar (*p)) && *p != '\0')
    {
      ++p;
    }

  *keyword = xstrndup (keyword_start, p - keyword_start);
  if (*p  == '\0')
    return;

  do
    {
      ++p;
    }
  while (isspace (to_uchar (*p)));

  if (*p == '\0' || *p == '#')
    return;

  arg_start = p;

  while (*p != '\0' && *p != '#')
    ++p;

  for (--p; isspace (to_uchar (*p)); --p)
    continue;
  ++p;

  *arg = xstrndup (arg_start, p - arg_start);
}

/* FIXME: Write a string to standard out, while watching for "dangerous"
   sequences like unescaped : and = characters.  */

static void
append_quoted (const char *str)
{
  bool need_backslash = true;

  while (*str != '\0')
    {
      switch (*str)
        {
        case '\'':
          APPEND_CHAR ('\'');
          APPEND_CHAR ('\\');
          APPEND_CHAR ('\'');
          need_backslash = true;
          break;

        case '\\':
        case '^':
          need_backslash = !need_backslash;
          break;

        case ':':
        case '=':
          if (need_backslash)
            APPEND_CHAR ('\\');
          /* Fall through */

        default:
          need_backslash = true;
          break;
        }

      APPEND_CHAR (*str);
      ++str;
    }
}

/* Read the file open on FP (with name FILENAME).  First, look for a
   'TERM name' directive where name matches the current terminal type.
   Once found, translate and accumulate the associated directives onto
   the global obstack LSC_OBSTACK.  Give a diagnostic
   upon failure (unrecognized keyword is the only way to fail here).
   Return true if successful.  */

static bool
dc_parse_stream (FILE *fp, const char *filename)
{
  size_t line_number = 0;
  char const *next_G_line = G_line;
  char *input_line = NULL;
  size_t input_line_size = 0;
  char const *line;
  char const *term;
  bool ok = true;

  /* State for the parser.  */
  enum { ST_TERMNO, ST_TERMYES, ST_TERMSURE, ST_GLOBAL } state = ST_GLOBAL;

  /* Get terminal type */
  term = getenv ("TERM");
  if (term == NULL || *term == '\0')
    term = "none";

  while (1)
    {
      char *keywd, *arg;
      bool unrecognized;

      ++line_number;

      if (fp)
        {
          if (getline (&input_line, &input_line_size, fp) <= 0)
            {
              free (input_line);
              break;
            }
          line = input_line;
        }
      else
        {
          if (next_G_line == G_line + sizeof G_line)
            break;
          line = next_G_line;
          next_G_line += strlen (next_G_line) + 1;
        }

      parse_line (line, &keywd, &arg);

      if (keywd == NULL)
        continue;

      if (arg == NULL)
        {
          error (0, 0, _("%s:%lu: invalid line;  missing second token"),
                 quotef (filename), (unsigned long int) line_number);
          ok = false;
          free (keywd);
          continue;
        }

      unrecognized = false;
      if (c_strcasecmp (keywd, "TERM") == 0)
        {
          if (fnmatch (arg, term, 0) == 0)
            state = ST_TERMSURE;
          else if (state != ST_TERMSURE)
            state = ST_TERMNO;
        }
      else
        {
          if (state == ST_TERMSURE)
            state = ST_TERMYES; /* Another TERM can cancel */

          if (state != ST_TERMNO)
            {
              if (keywd[0] == '.')
                {
                  APPEND_CHAR ('*');
                  append_quoted (keywd);
                  APPEND_CHAR ('=');
                  append_quoted (arg);
                  APPEND_CHAR (':');
                }
              else if (keywd[0] == '*')
                {
                  append_quoted (keywd);
                  APPEND_CHAR ('=');
                  append_quoted (arg);
                  APPEND_CHAR (':');
                }
              else if (c_strcasecmp (keywd, "OPTIONS") == 0
                       || c_strcasecmp (keywd, "COLOR") == 0
                       || c_strcasecmp (keywd, "EIGHTBIT") == 0)
                {
                  /* Ignore.  */
                }
              else
                {
                  int i;

                  for (i = 0; slack_codes[i] != NULL; ++i)
                    if (c_strcasecmp (keywd, slack_codes[i]) == 0)
                      break;

                  if (slack_codes[i] != NULL)
                    {
                      APPEND_TWO_CHAR_STRING (ls_codes[i]);
                      APPEND_CHAR ('=');
                      append_quoted (arg);
                      APPEND_CHAR (':');
                    }
                  else
                    {
                      unrecognized = true;
                    }
                }
            }
          else
            {
              unrecognized = true;
            }
        }

      if (unrecognized && (state == ST_TERMSURE || state == ST_TERMYES))
        {
          error (0, 0, _("%s:%lu: unrecognized keyword %s"),
                 (filename ? quotef (filename) : _("<internal>")),
                 (unsigned long int) line_number, keywd);
          ok = false;
        }

      free (keywd);
      free (arg);
    }

  return ok;
}

static bool
dc_parse_file (const char *filename)
{
  bool ok;

  if (! STREQ (filename, "-") && freopen (filename, "r", stdin) == NULL)
    {
      error (0, errno, "%s", quotef (filename));
      return false;
    }

  ok = dc_parse_stream (stdin, filename);

  if (fclose (stdin) != 0)
    {
      error (0, errno, "%s", quotef (filename));
      return false;
    }

  return ok;
}

int
main (int argc, char **argv)
{
  bool ok = true;
  int optc;
  enum Shell_syntax syntax = SHELL_SYNTAX_UNKNOWN;
  bool print_database = false;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  while ((optc = getopt_long (argc, argv, "bcp", long_options, NULL)) != -1)
    switch (optc)
      {
      case 'b':	/* Bourne shell syntax.  */
        syntax = SHELL_SYNTAX_BOURNE;
        break;

      case 'c':	/* C shell syntax.  */
        syntax = SHELL_SYNTAX_C;
        break;

      case 'p':
        print_database = true;
        break;

      case_GETOPT_HELP_CHAR;

      case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);

      default:
        usage (EXIT_FAILURE);
      }

  argc -= optind;
  argv += optind;

  /* It doesn't make sense to use --print with either of
     --bourne or --c-shell.  */
  if (print_database && syntax != SHELL_SYNTAX_UNKNOWN)
    {
      error (0, 0,
             _("the options to output dircolors' internal database and\n"
               "to select a shell syntax are mutually exclusive"));
      usage (EXIT_FAILURE);
    }

  if ((!print_database) < argc)
    {
      error (0, 0, _("extra operand %s"), quote (argv[!print_database]));
      if (print_database)
        fprintf (stderr, "%s\n",
                 _("file operands cannot be combined with "
                   "--print-database (-p)"));
      usage (EXIT_FAILURE);
    }

  if (print_database)
    {
      char const *p = G_line;
      while (p - G_line < sizeof G_line)
        {
          puts (p);
          p += strlen (p) + 1;
        }
    }
  else
    {
      /* If shell syntax was not explicitly specified, try to guess it. */
      if (syntax == SHELL_SYNTAX_UNKNOWN)
        {
          syntax = guess_shell_syntax ();
          if (syntax == SHELL_SYNTAX_UNKNOWN)
            {
              die (EXIT_FAILURE, 0,
         _("no SHELL environment variable, and no shell type option given"));
            }
        }

      obstack_init (&lsc_obstack);
      if (argc == 0)
        ok = dc_parse_stream (NULL, NULL);
      else
        ok = dc_parse_file (argv[0]);

      if (ok)
        {
          size_t len = obstack_object_size (&lsc_obstack);
          char *s = obstack_finish (&lsc_obstack);
          const char *prefix;
          const char *suffix;

          if (syntax == SHELL_SYNTAX_BOURNE)
            {
              prefix = "LS_COLORS='";
              suffix = "';\nexport LS_COLORS\n";
            }
          else
            {
              prefix = "setenv LS_COLORS '";
              suffix = "'\n";
            }
          fputs (prefix, stdout);
          fwrite (s, 1, len, stdout);
          fputs (suffix, stdout);
        }
    }

  return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
