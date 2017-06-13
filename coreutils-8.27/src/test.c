/* GNU test program (ksb and mjb) */

/* Modified to run with the GNU shell by bfox. */

/* Copyright (C) 1987-2017 Free Software Foundation, Inc.

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

/* Define TEST_STANDALONE to get the /bin/test version.  Otherwise, you get
   the shell builtin version. */

/* Without this pragma, gcc 4.6.2 20111027 mistakenly suggests that
   the advance function might be candidate for attribute 'pure'.  */
#if (__GNUC__ == 4 && 6 <= __GNUC_MINOR__) || 4 < __GNUC__
# pragma GCC diagnostic ignored "-Wsuggest-attribute=pure"
#endif

#include <config.h>
#include <stdio.h>
#include <sys/types.h>

#define TEST_STANDALONE 1

#ifndef LBRACKET
# define LBRACKET 0
#endif

/* The official name of this program (e.g., no 'g' prefix).  */
#if LBRACKET
# define PROGRAM_NAME "["
#else
# define PROGRAM_NAME "test"
#endif

#include "system.h"
#include "quote.h"
#include "stat-time.h"
#include "strnumcmp.h"

#include <stdarg.h>
#include "verror.h"

#if HAVE_SYS_PARAM_H
# include <sys/param.h>
#endif

/* Exit status for syntax errors, etc.  */
enum { TEST_TRUE, TEST_FALSE, TEST_FAILURE };

#if defined TEST_STANDALONE
# define test_exit(val) exit (val)
# define test_main_return(val) return val
#else
   static jmp_buf test_exit_buf;
   static int test_error_return = 0;
# define test_exit(val) test_error_return = val, longjmp (test_exit_buf, 1)
# define test_main_return(val) test_exit (val)
#endif /* !TEST_STANDALONE */

static int pos;		/* The offset of the current argument in ARGV. */
static int argc;	/* The number of arguments present in ARGV. */
static char **argv;	/* The argument list. */

static bool test_unop (char const *s);
static bool unary_operator (void);
static bool binary_operator (bool);
static bool two_arguments (void);
static bool three_arguments (void);
static bool posixtest (int);

static bool expr (void);
static bool term (void);
static bool and (void);
static bool or (void);

static void test_syntax_error (char const *format, ...)
     ATTRIBUTE_NORETURN;
static void beyond (void) ATTRIBUTE_NORETURN;

static void
test_syntax_error (char const *format, ...)
{
  va_list ap;
  va_start (ap, format);
  verror (0, 0, format, ap);
  test_exit (TEST_FAILURE);
}

/* Increment our position in the argument list.  Check that we're not
   past the end of the argument list.  This check is suppressed if the
   argument is false.  */

static void
advance (bool f)
{
  ++pos;

  if (f && pos >= argc)
    beyond ();
}

static void
unary_advance (void)
{
  advance (true);
  ++pos;
}

/*
 * beyond - call when we're beyond the end of the argument list (an
 *	error condition)
 */
static void
beyond (void)
{
  test_syntax_error (_("missing argument after %s"), quote (argv[argc - 1]));
}

/* If the characters pointed to by STRING constitute a valid number,
   return a pointer to the start of the number, skipping any blanks or
   leading '+'.  Otherwise, report an error and exit.  */
static char const *
find_int (char const *string)
{
  char const *p;
  char const *number_start;

  for (p = string; isblank (to_uchar (*p)); p++)
    continue;

  if (*p == '+')
    {
      p++;
      number_start = p;
    }
  else
    {
      number_start = p;
      p += (*p == '-');
    }

  if (ISDIGIT (*p++))
    {
      while (ISDIGIT (*p))
        p++;
      while (isblank (to_uchar (*p)))
        p++;
      if (!*p)
        return number_start;
    }

  test_syntax_error (_("invalid integer %s"), quote (string));
}

/* Find the modification time of FILE, and stuff it into *MTIME.
   Return true if successful.  */
static bool
get_mtime (char const *filename, struct timespec *mtime)
{
  struct stat finfo;
  bool ok = (stat (filename, &finfo) == 0);
#ifdef lint
  static struct timespec const zero;
  *mtime = zero;
#endif
  if (ok)
    *mtime = get_stat_mtime (&finfo);
  return ok;
}

/* Return true if S is one of the test command's binary operators.  */
static bool
binop (char const *s)
{
  return ((STREQ (s,   "=")) || (STREQ (s,  "!=")) || (STREQ (s, "==")) ||
          (STREQ (s,   "-nt")) ||
          (STREQ (s, "-ot")) || (STREQ (s, "-ef")) || (STREQ (s, "-eq")) ||
          (STREQ (s, "-ne")) || (STREQ (s, "-lt")) || (STREQ (s, "-le")) ||
          (STREQ (s, "-gt")) || (STREQ (s, "-ge")));
}

/*
 * term - parse a term and return 1 or 0 depending on whether the term
 *	evaluates to true or false, respectively.
 *
 * term ::=
 *	'-'('h'|'d'|'f'|'r'|'s'|'w'|'c'|'b'|'p'|'u'|'g'|'k') filename
 *	'-'('L'|'x') filename
 *	'-t' int
 *	'-'('z'|'n') string
 *	string
 *	string ('!='|'=') string
 *	<int> '-'(eq|ne|le|lt|ge|gt) <int>
 *	file '-'(nt|ot|ef) file
 *	'(' <expr> ')'
 * int ::=
 *	'-l' string
 *	positive and negative integers
 */
static bool
term (void)
{
  bool value;
  bool negated = false;

  /* Deal with leading 'not's.  */
  while (pos < argc && argv[pos][0] == '!' && argv[pos][1] == '\0')
    {
      advance (true);
      negated = !negated;
    }

  if (pos >= argc)
    beyond ();

  /* A paren-bracketed argument. */
  if (argv[pos][0] == '(' && argv[pos][1] == '\0')
    {
      int nargs;

      advance (true);

      for (nargs = 1;
           pos + nargs < argc && ! STREQ (argv[pos + nargs], ")");
           nargs++)
        if (nargs == 4)
          {
            nargs = argc - pos;
            break;
          }

      value = posixtest (nargs);
      if (argv[pos] == 0)
        test_syntax_error (_("%s expected"), quote (")"));
      else
        if (argv[pos][0] != ')' || argv[pos][1])
          test_syntax_error (_("%s expected, found %s"),
                             quote_n (0, ")"), quote_n (1, argv[pos]));
      advance (false);
    }

  /* Are there enough arguments left that this could be dyadic?  */
  else if (4 <= argc - pos && STREQ (argv[pos], "-l") && binop (argv[pos + 2]))
    value = binary_operator (true);
  else if (3 <= argc - pos && binop (argv[pos + 1]))
    value = binary_operator (false);

  /* It might be a switch type argument.  */
  else if (argv[pos][0] == '-' && argv[pos][1] && argv[pos][2] == '\0')
    {
      if (test_unop (argv[pos]))
        value = unary_operator ();
      else
        test_syntax_error (_("%s: unary operator expected"), quote (argv[pos]));
    }
  else
    {
      value = (argv[pos][0] != '\0');
      advance (false);
    }

  return negated ^ value;
}

static bool
binary_operator (bool l_is_l)
{
  int op;
  struct stat stat_buf, stat_spare;
  /* Is the right integer expression of the form '-l string'? */
  bool r_is_l;

  if (l_is_l)
    advance (false);
  op = pos + 1;

  if ((op < argc - 2) && STREQ (argv[op + 1], "-l"))
    {
      r_is_l = true;
      advance (false);
    }
  else
    r_is_l = false;

  if (argv[op][0] == '-')
    {
      /* check for eq, nt, and stuff */
      if ((((argv[op][1] == 'l' || argv[op][1] == 'g')
            && (argv[op][2] == 'e' || argv[op][2] == 't'))
           || (argv[op][1] == 'e' && argv[op][2] == 'q')
           || (argv[op][1] == 'n' && argv[op][2] == 'e'))
          && !argv[op][3])
        {
          char lbuf[INT_BUFSIZE_BOUND (uintmax_t)];
          char rbuf[INT_BUFSIZE_BOUND (uintmax_t)];
          char const *l = (l_is_l
                           ? umaxtostr (strlen (argv[op - 1]), lbuf)
                           : find_int (argv[op - 1]));
          char const *r = (r_is_l
                           ? umaxtostr (strlen (argv[op + 2]), rbuf)
                           : find_int (argv[op + 1]));
          int cmp = strintcmp (l, r);
          bool xe_operator = (argv[op][2] == 'e');
          pos += 3;
          return (argv[op][1] == 'l' ? cmp < xe_operator
                  : argv[op][1] == 'g' ? cmp > - xe_operator
                  : (cmp != 0) == xe_operator);
        }

      switch (argv[op][1])
        {
        default:
          break;

        case 'n':
          if (argv[op][2] == 't' && !argv[op][3])
            {
              /* nt - newer than */
              struct timespec lt, rt;
              bool le, re;
              pos += 3;
              if (l_is_l || r_is_l)
                test_syntax_error (_("-nt does not accept -l"), NULL);
              le = get_mtime (argv[op - 1], &lt);
              re = get_mtime (argv[op + 1], &rt);
              return le && (!re || timespec_cmp (lt, rt) > 0);
            }
          break;

        case 'e':
          if (argv[op][2] == 'f' && !argv[op][3])
            {
              /* ef - hard link? */
              pos += 3;
              if (l_is_l || r_is_l)
                test_syntax_error (_("-ef does not accept -l"), NULL);
              return (stat (argv[op - 1], &stat_buf) == 0
                      && stat (argv[op + 1], &stat_spare) == 0
                      && stat_buf.st_dev == stat_spare.st_dev
                      && stat_buf.st_ino == stat_spare.st_ino);
            }
          break;

        case 'o':
          if ('t' == argv[op][2] && '\000' == argv[op][3])
            {
              /* ot - older than */
              struct timespec lt, rt;
              bool le, re;
              pos += 3;
              if (l_is_l || r_is_l)
                test_syntax_error (_("-ot does not accept -l"), NULL);
              le = get_mtime (argv[op - 1], &lt);
              re = get_mtime (argv[op + 1], &rt);
              return re && (!le || timespec_cmp (lt, rt) < 0);
            }
          break;
        }

      /* FIXME: is this dead code? */
      test_syntax_error (_("%s: unknown binary operator"), quote (argv[op]));
    }

  if (argv[op][0] == '='
      && (!argv[op][1] || ((argv[op][1] == '=') && !argv[op][2])))
    {
      bool value = STREQ (argv[pos], argv[pos + 2]);
      pos += 3;
      return value;
    }

  if (STREQ (argv[op], "!="))
    {
      bool value = !STREQ (argv[pos], argv[pos + 2]);
      pos += 3;
      return value;
    }

  /* Not reached.  */
  abort ();
}

static bool
unary_operator (void)
{
  struct stat stat_buf;

  switch (argv[pos][1])
    {
    default:
      return false;

      /* All of the following unary operators use unary_advance (), which
         checks to make sure that there is an argument, and then advances
         pos right past it.  This means that pos - 1 is the location of the
         argument. */

    case 'a':			/* file exists in the file system? */
    case 'e':
      unary_advance ();
      return stat (argv[pos - 1], &stat_buf) == 0;

    case 'r':			/* file is readable? */
      unary_advance ();
      return euidaccess (argv[pos - 1], R_OK) == 0;

    case 'w':			/* File is writable? */
      unary_advance ();
      return euidaccess (argv[pos - 1], W_OK) == 0;

    case 'x':			/* File is executable? */
      unary_advance ();
      return euidaccess (argv[pos - 1], X_OK) == 0;

    case 'O':			/* File is owned by you? */
      {
        unary_advance ();
        if (stat (argv[pos - 1], &stat_buf) != 0)
          return false;
        errno = 0;
        uid_t euid = geteuid ();
        uid_t NO_UID = -1;
        return ! (euid == NO_UID && errno) && euid == stat_buf.st_uid;
      }

    case 'G':			/* File is owned by your group? */
      {
        unary_advance ();
        if (stat (argv[pos - 1], &stat_buf) != 0)
          return false;
        errno = 0;
        gid_t egid = getegid ();
        gid_t NO_GID = -1;
        return ! (egid == NO_GID && errno) && egid == stat_buf.st_gid;
      }

    case 'f':			/* File is a file? */
      unary_advance ();
      /* Under POSIX, -f is true if the given file exists
         and is a regular file. */
      return (stat (argv[pos - 1], &stat_buf) == 0
              && S_ISREG (stat_buf.st_mode));

    case 'd':			/* File is a directory? */
      unary_advance ();
      return (stat (argv[pos - 1], &stat_buf) == 0
              && S_ISDIR (stat_buf.st_mode));

    case 's':			/* File has something in it? */
      unary_advance ();
      return (stat (argv[pos - 1], &stat_buf) == 0
              && 0 < stat_buf.st_size);

    case 'S':			/* File is a socket? */
      unary_advance ();
      return (stat (argv[pos - 1], &stat_buf) == 0
              && S_ISSOCK (stat_buf.st_mode));

    case 'c':			/* File is character special? */
      unary_advance ();
      return (stat (argv[pos - 1], &stat_buf) == 0
              && S_ISCHR (stat_buf.st_mode));

    case 'b':			/* File is block special? */
      unary_advance ();
      return (stat (argv[pos - 1], &stat_buf) == 0
              && S_ISBLK (stat_buf.st_mode));

    case 'p':			/* File is a named pipe? */
      unary_advance ();
      return (stat (argv[pos - 1], &stat_buf) == 0
              && S_ISFIFO (stat_buf.st_mode));

    case 'L':			/* Same as -h  */
      /*FALLTHROUGH*/

    case 'h':			/* File is a symbolic link? */
      unary_advance ();
      return (lstat (argv[pos - 1], &stat_buf) == 0
              && S_ISLNK (stat_buf.st_mode));

    case 'u':			/* File is setuid? */
      unary_advance ();
      return (stat (argv[pos - 1], &stat_buf) == 0
              && (stat_buf.st_mode & S_ISUID));

    case 'g':			/* File is setgid? */
      unary_advance ();
      return (stat (argv[pos - 1], &stat_buf) == 0
              && (stat_buf.st_mode & S_ISGID));

    case 'k':			/* File has sticky bit set? */
      unary_advance ();
      return (stat (argv[pos - 1], &stat_buf) == 0
              && (stat_buf.st_mode & S_ISVTX));

    case 't':			/* File (fd) is a terminal? */
      {
        long int fd;
        char const *arg;
        unary_advance ();
        arg = find_int (argv[pos - 1]);
        errno = 0;
        fd = strtol (arg, NULL, 10);
        return (errno != ERANGE && 0 <= fd && fd <= INT_MAX && isatty (fd));
      }

    case 'n':			/* True if arg has some length. */
      unary_advance ();
      return argv[pos - 1][0] != 0;

    case 'z':			/* True if arg has no length. */
      unary_advance ();
      return argv[pos - 1][0] == '\0';
    }
}

/*
 * and:
 *	term
 *	term '-a' and
 */
static bool
and (void)
{
  bool value = true;

  while (true)
    {
      value &= term ();
      if (! (pos < argc && STREQ (argv[pos], "-a")))
        return value;
      advance (false);
    }
}

/*
 * or:
 *	and
 *	and '-o' or
 */
static bool
or (void)
{
  bool value = false;

  while (true)
    {
      value |= and ();
      if (! (pos < argc && STREQ (argv[pos], "-o")))
        return value;
      advance (false);
    }
}

/*
 * expr:
 *	or
 */
static bool
expr (void)
{
  if (pos >= argc)
    beyond ();

  return or ();		/* Same with this. */
}

/* Return true if OP is one of the test command's unary operators. */
static bool
test_unop (char const *op)
{
  if (op[0] != '-')
    return false;

  switch (op[1])
    {
    case 'a': case 'b': case 'c': case 'd': case 'e':
    case 'f': case 'g': case 'h': case 'k': case 'n':
    case 'o': case 'p': case 'r': case 's': case 't':
    case 'u': case 'w': case 'x': case 'z':
    case 'G': case 'L': case 'O': case 'S': case 'N':
      return true;
    default:
      return false;
    }
}

static bool
one_argument (void)
{
  return argv[pos++][0] != '\0';
}

static bool
two_arguments (void)
{
  bool value;

  if (STREQ (argv[pos], "!"))
    {
      advance (false);
      value = ! one_argument ();
    }
  else if (argv[pos][0] == '-'
           && argv[pos][1] != '\0'
           && argv[pos][2] == '\0')
    {
      if (test_unop (argv[pos]))
        value = unary_operator ();
      else
        test_syntax_error (_("%s: unary operator expected"), quote (argv[pos]));
    }
  else
    beyond ();
  return (value);
}

static bool
three_arguments (void)
{
  bool value;

  if (binop (argv[pos + 1]))
    value = binary_operator (false);
  else if (STREQ (argv[pos], "!"))
    {
      advance (true);
      value = !two_arguments ();
    }
  else if (STREQ (argv[pos], "(") && STREQ (argv[pos + 2], ")"))
    {
      advance (false);
      value = one_argument ();
      advance (false);
    }
  else if (STREQ (argv[pos + 1], "-a") || STREQ (argv[pos + 1], "-o"))
    value = expr ();
  else
    test_syntax_error (_("%s: binary operator expected"), quote (argv[pos+1]));
  return (value);
}

/* This is an implementation of a Posix.2 proposal by David Korn. */
static bool
posixtest (int nargs)
{
  bool value;

  switch (nargs)
    {
      case 1:
        value = one_argument ();
        break;

      case 2:
        value = two_arguments ();
        break;

      case 3:
        value = three_arguments ();
        break;

      case 4:
        if (STREQ (argv[pos], "!"))
          {
            advance (true);
            value = !three_arguments ();
            break;
          }
        if (STREQ (argv[pos], "(") && STREQ (argv[pos + 3], ")"))
          {
            advance (false);
            value = two_arguments ();
            advance (false);
            break;
          }
        /* FALLTHROUGH */
      case 5:
      default:
        if (nargs <= 0)
          abort ();
        value = expr ();
    }

  return (value);
}

#if defined TEST_STANDALONE

void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      fputs (_("\
Usage: test EXPRESSION\n\
  or:  test\n\
  or:  [ EXPRESSION ]\n\
  or:  [ ]\n\
  or:  [ OPTION\n\
"), stdout);
      fputs (_("\
Exit with the status determined by EXPRESSION.\n\
\n\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      fputs (_("\
\n\
An omitted EXPRESSION defaults to false.  Otherwise,\n\
EXPRESSION is true or false and sets exit status.  It is one of:\n\
"), stdout);
      fputs (_("\
\n\
  ( EXPRESSION )               EXPRESSION is true\n\
  ! EXPRESSION                 EXPRESSION is false\n\
  EXPRESSION1 -a EXPRESSION2   both EXPRESSION1 and EXPRESSION2 are true\n\
  EXPRESSION1 -o EXPRESSION2   either EXPRESSION1 or EXPRESSION2 is true\n\
"), stdout);
      fputs (_("\
\n\
  -n STRING            the length of STRING is nonzero\n\
  STRING               equivalent to -n STRING\n\
  -z STRING            the length of STRING is zero\n\
  STRING1 = STRING2    the strings are equal\n\
  STRING1 != STRING2   the strings are not equal\n\
"), stdout);
      fputs (_("\
\n\
  INTEGER1 -eq INTEGER2   INTEGER1 is equal to INTEGER2\n\
  INTEGER1 -ge INTEGER2   INTEGER1 is greater than or equal to INTEGER2\n\
  INTEGER1 -gt INTEGER2   INTEGER1 is greater than INTEGER2\n\
  INTEGER1 -le INTEGER2   INTEGER1 is less than or equal to INTEGER2\n\
  INTEGER1 -lt INTEGER2   INTEGER1 is less than INTEGER2\n\
  INTEGER1 -ne INTEGER2   INTEGER1 is not equal to INTEGER2\n\
"), stdout);
      fputs (_("\
\n\
  FILE1 -ef FILE2   FILE1 and FILE2 have the same device and inode numbers\n\
  FILE1 -nt FILE2   FILE1 is newer (modification date) than FILE2\n\
  FILE1 -ot FILE2   FILE1 is older than FILE2\n\
"), stdout);
      fputs (_("\
\n\
  -b FILE     FILE exists and is block special\n\
  -c FILE     FILE exists and is character special\n\
  -d FILE     FILE exists and is a directory\n\
  -e FILE     FILE exists\n\
"), stdout);
      fputs (_("\
  -f FILE     FILE exists and is a regular file\n\
  -g FILE     FILE exists and is set-group-ID\n\
  -G FILE     FILE exists and is owned by the effective group ID\n\
  -h FILE     FILE exists and is a symbolic link (same as -L)\n\
  -k FILE     FILE exists and has its sticky bit set\n\
"), stdout);
      fputs (_("\
  -L FILE     FILE exists and is a symbolic link (same as -h)\n\
  -O FILE     FILE exists and is owned by the effective user ID\n\
  -p FILE     FILE exists and is a named pipe\n\
  -r FILE     FILE exists and read permission is granted\n\
  -s FILE     FILE exists and has a size greater than zero\n\
"), stdout);
      fputs (_("\
  -S FILE     FILE exists and is a socket\n\
  -t FD       file descriptor FD is opened on a terminal\n\
  -u FILE     FILE exists and its set-user-ID bit is set\n\
  -w FILE     FILE exists and write permission is granted\n\
  -x FILE     FILE exists and execute (or search) permission is granted\n\
"), stdout);
      fputs (_("\
\n\
Except for -h and -L, all FILE-related tests dereference symbolic links.\n\
Beware that parentheses need to be escaped (e.g., by backslashes) for shells.\n\
INTEGER may also be -l STRING, which evaluates to the length of STRING.\n\
"), stdout);
      fputs (_("\
\n\
NOTE: Binary -a and -o are inherently ambiguous.  Use 'test EXPR1 && test\n\
EXPR2' or 'test EXPR1 || test EXPR2' instead.\n\
"), stdout);
      fputs (_("\
\n\
NOTE: [ honors the --help and --version options, but test does not.\n\
test treats each of those as it treats any other nonempty STRING.\n\
"), stdout);
      printf (USAGE_BUILTIN_WARNING, _("test and/or ["));
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}
#endif /* TEST_STANDALONE */

#if !defined TEST_STANDALONE
# define main test_command
#endif

#define AUTHORS \
  proper_name ("Kevin Braunsdorf"), \
  proper_name ("Matthew Bradburn")

/*
 * [:
 *	'[' expr ']'
 * test:
 *	test expr
 */
int
main (int margc, char **margv)
{
  bool value;

#if !defined TEST_STANDALONE
  int code;

  code = setjmp (test_exit_buf);

  if (code)
    return (test_error_return);
#else /* TEST_STANDALONE */
  initialize_main (&margc, &margv);
  set_program_name (margv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  initialize_exit_failure (TEST_FAILURE);
  atexit (close_stdout);
#endif /* TEST_STANDALONE */

  argv = margv;

  if (LBRACKET)
    {
      /* Recognize --help or --version, but only when invoked in the
         "[" form, when the last argument is not "]".  Use direct
         parsing, rather than parse_long_options, to avoid accepting
         abbreviations.  POSIX allows "[ --help" and "[ --version" to
         have the usual GNU behavior, but it requires "test --help"
         and "test --version" to exit silently with status 0.  */
      if (margc == 2)
        {
          if (STREQ (margv[1], "--help"))
            usage (EXIT_SUCCESS);

          if (STREQ (margv[1], "--version"))
            {
              version_etc (stdout, PROGRAM_NAME, PACKAGE_NAME, Version, AUTHORS,
                           (char *) NULL);
              test_main_return (EXIT_SUCCESS);
            }
        }
      if (margc < 2 || !STREQ (margv[margc - 1], "]"))
        test_syntax_error (_("missing %s"), quote ("]"));

      --margc;
    }

  argc = margc;
  pos = 1;

  if (pos >= argc)
    test_main_return (TEST_FALSE);

  value = posixtest (argc - 1);

  if (pos != argc)
    test_syntax_error (_("extra argument %s"), quote (argv[pos]));

  test_main_return (value ? TEST_TRUE : TEST_FALSE);
}
