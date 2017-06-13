/* expr -- evaluate expressions.
   Copyright (C) 1986-2017 Free Software Foundation, Inc.

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

/* Author: Mike Parker.
   Modified for arbitrary-precision calculation by James Youngman.

   This program evaluates expressions.  Each token (operator, operand,
   parenthesis) of the expression must be a separate argument.  The
   parser used is a reasonably general one, though any incarnation of
   it is language-specific.  It is especially nice for expressions.

   No parse tree is needed; a new node is evaluated immediately.
   One function can handle multiple operators all of equal precedence,
   provided they all associate ((x op x) op x).

   Define EVAL_TRACE to print an evaluation trace.  */

#include <config.h>
#include <stdio.h>
#include <sys/types.h>
#include "system.h"

#include <regex.h>
#include "die.h"
#include "error.h"
#include "long-options.h"
#include "strnumcmp.h"
#include "xstrtol.h"

/* Various parts of this code assume size_t fits into unsigned long
   int, the widest unsigned type that GMP supports.  */
verify (SIZE_MAX <= ULONG_MAX);

#ifndef HAVE_GMP
# define HAVE_GMP 0
#endif

#if HAVE_GMP
# include <gmp.h>
#else
static void integer_overflow (char) ATTRIBUTE_NORETURN;
/* Approximate gmp.h well enough for expr.c's purposes.  */
typedef intmax_t mpz_t[1];
static void mpz_clear (mpz_t z) { (void) z; }
static void mpz_init_set_ui (mpz_t z, unsigned long int i) { z[0] = i; }
static int
mpz_init_set_str (mpz_t z, char *s, int base)
{
  return xstrtoimax (s, NULL, base, z, NULL) == LONGINT_OK ? 0 : -1;
}
static void
mpz_add (mpz_t r, mpz_t a0, mpz_t b0)
{
  intmax_t a = a0[0];
  intmax_t b = b0[0];
  intmax_t val = a + b;
  if ((val < a) != (b < 0))
    integer_overflow ('+');
  r[0] = val;
}
static void
mpz_sub (mpz_t r, mpz_t a0, mpz_t b0)
{
  intmax_t a = a0[0];
  intmax_t b = b0[0];
  intmax_t val = a - b;
  if ((a < val) != (b < 0))
    integer_overflow ('-');
  r[0] = val;
}
static void
mpz_mul (mpz_t r, mpz_t a0, mpz_t b0)
{
  intmax_t a = a0[0];
  intmax_t b = b0[0];
  intmax_t val = a * b;
  if (! (a == 0 || b == 0
         || ((val < 0) == ((a < 0) ^ (b < 0)) && val / a == b)))
    integer_overflow ('*');
  r[0] = val;
}
static void
mpz_tdiv_q (mpz_t r, mpz_t a0, mpz_t b0)
{
  intmax_t a = a0[0];
  intmax_t b = b0[0];

  /* Some x86-style hosts raise an exception for INT_MIN / -1.  */
  if (a < - INTMAX_MAX && b == -1)
    integer_overflow ('/');
  r[0] = a / b;
}
static void
mpz_tdiv_r (mpz_t r, mpz_t a0, mpz_t b0)
{
  intmax_t a = a0[0];
  intmax_t b = b0[0];

  /* Some x86-style hosts raise an exception for INT_MIN % -1.  */
  r[0] = a < - INTMAX_MAX && b == -1 ? 0 : a % b;
}
static char *
mpz_get_str (char const *str, int base, mpz_t z)
{
  (void) str; (void) base;
  char buf[INT_BUFSIZE_BOUND (intmax_t)];
  return xstrdup (imaxtostr (z[0], buf));
}
static int
mpz_sgn (mpz_t z)
{
  return z[0] < 0 ? -1 : 0 < z[0];
}
static int
mpz_fits_ulong_p (mpz_t z)
{
  return 0 <= z[0] && z[0] <= ULONG_MAX;
}
static unsigned long int
mpz_get_ui (mpz_t z)
{
  return z[0];
}
static int
mpz_out_str (FILE *stream, int base, mpz_t z)
{
  (void) base;
  char buf[INT_BUFSIZE_BOUND (intmax_t)];
  return fputs (imaxtostr (z[0], buf), stream) != EOF;
}
#endif

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "expr"

#define AUTHORS \
  proper_name ("Mike Parker"), \
  proper_name ("James Youngman"), \
  proper_name ("Paul Eggert")

/* Exit statuses.  */
enum
  {
    /* Invalid expression: e.g., its form does not conform to the
       grammar for expressions.  Our grammar is an extension of the
       POSIX grammar.  */
    EXPR_INVALID = 2,

    /* An internal error occurred, e.g., arithmetic overflow, storage
       exhaustion.  */
    EXPR_FAILURE
  };

/* The kinds of value we can have.  */
enum valtype
{
  integer,
  string
};
typedef enum valtype TYPE;

/* A value is.... */
struct valinfo
{
  TYPE type;			/* Which kind. */
  union
  {				/* The value itself. */
    mpz_t i;
    char *s;
  } u;
};
typedef struct valinfo VALUE;

/* The arguments given to the program, minus the program name.  */
static char **args;

static VALUE *eval (bool);
static bool nomoreargs (void);
static bool null (VALUE *v);
static void printv (VALUE *v);

void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("\
Usage: %s EXPRESSION\n\
  or:  %s OPTION\n\
"),
              program_name, program_name);
      putchar ('\n');
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      fputs (_("\
\n\
Print the value of EXPRESSION to standard output.  A blank line below\n\
separates increasing precedence groups.  EXPRESSION may be:\n\
\n\
  ARG1 | ARG2       ARG1 if it is neither null nor 0, otherwise ARG2\n\
\n\
  ARG1 & ARG2       ARG1 if neither argument is null or 0, otherwise 0\n\
"), stdout);
      fputs (_("\
\n\
  ARG1 < ARG2       ARG1 is less than ARG2\n\
  ARG1 <= ARG2      ARG1 is less than or equal to ARG2\n\
  ARG1 = ARG2       ARG1 is equal to ARG2\n\
  ARG1 != ARG2      ARG1 is unequal to ARG2\n\
  ARG1 >= ARG2      ARG1 is greater than or equal to ARG2\n\
  ARG1 > ARG2       ARG1 is greater than ARG2\n\
"), stdout);
      fputs (_("\
\n\
  ARG1 + ARG2       arithmetic sum of ARG1 and ARG2\n\
  ARG1 - ARG2       arithmetic difference of ARG1 and ARG2\n\
"), stdout);
      /* Tell xgettext that the "% A" below is not a printf-style
         format string:  xgettext:no-c-format */
      fputs (_("\
\n\
  ARG1 * ARG2       arithmetic product of ARG1 and ARG2\n\
  ARG1 / ARG2       arithmetic quotient of ARG1 divided by ARG2\n\
  ARG1 % ARG2       arithmetic remainder of ARG1 divided by ARG2\n\
"), stdout);
      fputs (_("\
\n\
  STRING : REGEXP   anchored pattern match of REGEXP in STRING\n\
\n\
  match STRING REGEXP        same as STRING : REGEXP\n\
  substr STRING POS LENGTH   substring of STRING, POS counted from 1\n\
  index STRING CHARS         index in STRING where any CHARS is found, or 0\n\
  length STRING              length of STRING\n\
"), stdout);
      fputs (_("\
  + TOKEN                    interpret TOKEN as a string, even if it is a\n\
                               keyword like 'match' or an operator like '/'\n\
\n\
  ( EXPRESSION )             value of EXPRESSION\n\
"), stdout);
      fputs (_("\
\n\
Beware that many operators need to be escaped or quoted for shells.\n\
Comparisons are arithmetic if both ARGs are numbers, else lexicographical.\n\
Pattern matches return the string matched between \\( and \\) or null; if\n\
\\( and \\) are not used, they return the number of characters matched or 0.\n\
"), stdout);
      fputs (_("\
\n\
Exit status is 0 if EXPRESSION is neither null nor 0, 1 if EXPRESSION is null\n\
or 0, 2 if EXPRESSION is syntactically invalid, and 3 if an error occurred.\n\
"), stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

/* Report a syntax error and exit.  */
static void
syntax_error (void)
{
  die (EXPR_INVALID, 0, _("syntax error"));
}

#if ! HAVE_GMP
/* Report an integer overflow for operation OP and exit.  */
static void
integer_overflow (char op)
{
  die (EXPR_FAILURE, ERANGE, "%c", op);
}
#endif

int
main (int argc, char **argv)
{
  VALUE *v;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  initialize_exit_failure (EXPR_FAILURE);
  atexit (close_stdout);

  parse_long_options (argc, argv, PROGRAM_NAME, PACKAGE_NAME, VERSION,
                      usage, AUTHORS, (char const *) NULL);

  /* The above handles --help and --version.
     Since there is no other invocation of getopt, handle '--' here.  */
  unsigned int u_argc = argc;
  if (1 < u_argc && STREQ (argv[1], "--"))
    {
      --u_argc;
      ++argv;
    }

  if (u_argc <= 1)
    {
      error (0, 0, _("missing operand"));
      usage (EXPR_INVALID);
    }

  args = argv + 1;

  v = eval (true);
  if (!nomoreargs ())
    syntax_error ();
  printv (v);

  return null (v);
}

/* Return a VALUE for I.  */

static VALUE *
int_value (unsigned long int i)
{
  VALUE *v = xmalloc (sizeof *v);
  v->type = integer;
  mpz_init_set_ui (v->u.i, i);
  return v;
}

/* Return a VALUE for S.  */

static VALUE *
str_value (char const *s)
{
  VALUE *v = xmalloc (sizeof *v);
  v->type = string;
  v->u.s = xstrdup (s);
  return v;
}

/* Free VALUE V, including structure components.  */

static void
freev (VALUE *v)
{
  if (v->type == string)
    free (v->u.s);
  else
    mpz_clear (v->u.i);
  free (v);
}

/* Print VALUE V.  */

static void
printv (VALUE *v)
{
  switch (v->type)
    {
    case integer:
      mpz_out_str (stdout, 10, v->u.i);
      putchar ('\n');
      break;
    case string:
      puts (v->u.s);
      break;
    default:
      abort ();
    }
}

/* Return true if V is a null-string or zero-number.  */

static bool _GL_ATTRIBUTE_PURE
null (VALUE *v)
{
  switch (v->type)
    {
    case integer:
      return mpz_sgn (v->u.i) == 0;
    case string:
      {
        char const *cp = v->u.s;
        if (*cp == '\0')
          return true;

        cp += (*cp == '-');

        do
          {
            if (*cp != '0')
              return false;
          }
        while (*++cp);

        return true;
      }
    default:
      abort ();
    }
}

/* Return true if CP takes the form of an integer.  */

static bool _GL_ATTRIBUTE_PURE
looks_like_integer (char const *cp)
{
  cp += (*cp == '-');

  do
    if (! ISDIGIT (*cp))
      return false;
  while (*++cp);

  return true;
}

/* Coerce V to a string value (can't fail).  */

static void
tostring (VALUE *v)
{
  switch (v->type)
    {
    case integer:
      {
        char *s = mpz_get_str (NULL, 10, v->u.i);
        mpz_clear (v->u.i);
        v->u.s = s;
        v->type = string;
      }
      break;
    case string:
      break;
    default:
      abort ();
    }
}

/* Coerce V to an integer value.  Return true on success, false on failure.  */

static bool
toarith (VALUE *v)
{
  switch (v->type)
    {
    case integer:
      return true;
    case string:
      {
        char *s = v->u.s;

        if (! looks_like_integer (s))
          return false;
        if (mpz_init_set_str (v->u.i, s, 10) != 0 && !HAVE_GMP)
          die (EXPR_FAILURE, ERANGE, "%s", (s));
        free (s);
        v->type = integer;
        return true;
      }
    default:
      abort ();
    }
}

/* Extract a size_t value from an integer value I.
   If the value is negative, return SIZE_MAX.
   If the value is too large, return SIZE_MAX - 1.  */
static size_t
getsize (mpz_t i)
{
  if (mpz_sgn (i) < 0)
    return SIZE_MAX;
  if (mpz_fits_ulong_p (i))
    {
      unsigned long int ul = mpz_get_ui (i);
      if (ul < SIZE_MAX)
        return ul;
    }
  return SIZE_MAX - 1;
}

/* Return true and advance if the next token matches STR exactly.
   STR must not be NULL.  */

static bool
nextarg (char const *str)
{
  if (*args == NULL)
    return false;
  else
    {
      bool r = STREQ (*args, str);
      args += r;
      return r;
    }
}

/* Return true if there no more tokens.  */

static bool
nomoreargs (void)
{
  return *args == 0;
}

#ifdef EVAL_TRACE
/* Print evaluation trace and args remaining.  */

static void
trace (fxn)
     char *fxn;
{
  char **a;

  printf ("%s:", fxn);
  for (a = args; *a; a++)
    printf (" %s", *a);
  putchar ('\n');
}
#endif

/* Do the : operator.
   SV is the VALUE for the lhs (the string),
   PV is the VALUE for the rhs (the pattern).  */

static VALUE *
docolon (VALUE *sv, VALUE *pv)
{
  VALUE *v IF_LINT ( = NULL);
  const char *errmsg;
  struct re_pattern_buffer re_buffer;
  char fastmap[UCHAR_MAX + 1];
  struct re_registers re_regs;
  regoff_t matchlen;

  tostring (sv);
  tostring (pv);

  re_regs.num_regs = 0;
  re_regs.start = NULL;
  re_regs.end = NULL;

  re_buffer.buffer = NULL;
  re_buffer.allocated = 0;
  re_buffer.fastmap = fastmap;
  re_buffer.translate = NULL;
  re_syntax_options =
    RE_SYNTAX_POSIX_BASIC & ~RE_CONTEXT_INVALID_DUP & ~RE_NO_EMPTY_RANGES;
  errmsg = re_compile_pattern (pv->u.s, strlen (pv->u.s), &re_buffer);
  if (errmsg)
    die (EXPR_INVALID, 0, "%s", (errmsg));
  re_buffer.newline_anchor = 0;

  matchlen = re_match (&re_buffer, sv->u.s, strlen (sv->u.s), 0, &re_regs);
  if (0 <= matchlen)
    {
      /* Were \(...\) used? */
      if (re_buffer.re_nsub > 0)
        {
          sv->u.s[re_regs.end[1]] = '\0';
          v = str_value (sv->u.s + re_regs.start[1]);
        }
      else
        v = int_value (matchlen);
    }
  else if (matchlen == -1)
    {
      /* Match failed -- return the right kind of null.  */
      if (re_buffer.re_nsub > 0)
        v = str_value ("");
      else
        v = int_value (0);
    }
  else
    die (EXPR_FAILURE,
         (matchlen == -2 ? errno : EOVERFLOW),
         _("error in regular expression matcher"));

  if (0 < re_regs.num_regs)
    {
      free (re_regs.start);
      free (re_regs.end);
    }
  re_buffer.fastmap = NULL;
  regfree (&re_buffer);
  return v;
}

/* Handle bare operands and ( expr ) syntax.  */

static VALUE *
eval7 (bool evaluate)
{
  VALUE *v;

#ifdef EVAL_TRACE
  trace ("eval7");
#endif
  if (nomoreargs ())
    syntax_error ();

  if (nextarg ("("))
    {
      v = eval (evaluate);
      if (!nextarg (")"))
        syntax_error ();
      return v;
    }

  if (nextarg (")"))
    syntax_error ();

  return str_value (*args++);
}

/* Handle match, substr, index, and length keywords, and quoting "+".  */

static VALUE *
eval6 (bool evaluate)
{
  VALUE *l;
  VALUE *r;
  VALUE *v;
  VALUE *i1;
  VALUE *i2;

#ifdef EVAL_TRACE
  trace ("eval6");
#endif
  if (nextarg ("+"))
    {
      if (nomoreargs ())
        syntax_error ();
      return str_value (*args++);
    }
  else if (nextarg ("length"))
    {
      r = eval6 (evaluate);
      tostring (r);
      v = int_value (strlen (r->u.s));
      freev (r);
      return v;
    }
  else if (nextarg ("match"))
    {
      l = eval6 (evaluate);
      r = eval6 (evaluate);
      if (evaluate)
        {
          v = docolon (l, r);
          freev (l);
        }
      else
        v = l;
      freev (r);
      return v;
    }
  else if (nextarg ("index"))
    {
      size_t pos;

      l = eval6 (evaluate);
      r = eval6 (evaluate);
      tostring (l);
      tostring (r);
      pos = strcspn (l->u.s, r->u.s);
      v = int_value (l->u.s[pos] ? pos + 1 : 0);
      freev (l);
      freev (r);
      return v;
    }
  else if (nextarg ("substr"))
    {
      size_t llen;
      l = eval6 (evaluate);
      i1 = eval6 (evaluate);
      i2 = eval6 (evaluate);
      tostring (l);
      llen = strlen (l->u.s);

      if (!toarith (i1) || !toarith (i2))
        v = str_value ("");
      else
        {
          size_t pos = getsize (i1->u.i);
          size_t len = getsize (i2->u.i);

          if (llen < pos || pos == 0 || len == 0 || len == SIZE_MAX)
            v = str_value ("");
          else
            {
              size_t vlen = MIN (len, llen - pos + 1);
              char *vlim;
              v = xmalloc (sizeof *v);
              v->type = string;
              v->u.s = xmalloc (vlen + 1);
              vlim = mempcpy (v->u.s, l->u.s + pos - 1, vlen);
              *vlim = '\0';
            }
        }
      freev (l);
      freev (i1);
      freev (i2);
      return v;
    }
  else
    return eval7 (evaluate);
}

/* Handle : operator (pattern matching).
   Calls docolon to do the real work.  */

static VALUE *
eval5 (bool evaluate)
{
  VALUE *l;
  VALUE *r;
  VALUE *v;

#ifdef EVAL_TRACE
  trace ("eval5");
#endif
  l = eval6 (evaluate);
  while (1)
    {
      if (nextarg (":"))
        {
          r = eval6 (evaluate);
          if (evaluate)
            {
              v = docolon (l, r);
              freev (l);
              l = v;
            }
          freev (r);
        }
      else
        return l;
    }
}

/* Handle *, /, % operators.  */

static VALUE *
eval4 (bool evaluate)
{
  VALUE *l;
  VALUE *r;
  enum { multiply, divide, mod } fxn;

#ifdef EVAL_TRACE
  trace ("eval4");
#endif
  l = eval5 (evaluate);
  while (1)
    {
      if (nextarg ("*"))
        fxn = multiply;
      else if (nextarg ("/"))
        fxn = divide;
      else if (nextarg ("%"))
        fxn = mod;
      else
        return l;
      r = eval5 (evaluate);
      if (evaluate)
        {
          if (!toarith (l) || !toarith (r))
            die (EXPR_INVALID, 0, _("non-integer argument"));
          if (fxn != multiply && mpz_sgn (r->u.i) == 0)
            die (EXPR_INVALID, 0, _("division by zero"));
          ((fxn == multiply ? mpz_mul
            : fxn == divide ? mpz_tdiv_q
            : mpz_tdiv_r)
           (l->u.i, l->u.i, r->u.i));
        }
      freev (r);
    }
}

/* Handle +, - operators.  */

static VALUE *
eval3 (bool evaluate)
{
  VALUE *l;
  VALUE *r;
  enum { plus, minus } fxn;

#ifdef EVAL_TRACE
  trace ("eval3");
#endif
  l = eval4 (evaluate);
  while (1)
    {
      if (nextarg ("+"))
        fxn = plus;
      else if (nextarg ("-"))
        fxn = minus;
      else
        return l;
      r = eval4 (evaluate);
      if (evaluate)
        {
          if (!toarith (l) || !toarith (r))
            die (EXPR_INVALID, 0, _("non-integer argument"));
          (fxn == plus ? mpz_add : mpz_sub) (l->u.i, l->u.i, r->u.i);
        }
      freev (r);
    }
}

/* Handle comparisons.  */

static VALUE *
eval2 (bool evaluate)
{
  VALUE *l;

#ifdef EVAL_TRACE
  trace ("eval2");
#endif
  l = eval3 (evaluate);
  while (1)
    {
      VALUE *r;
      enum
        {
          less_than, less_equal, equal, not_equal, greater_equal, greater_than
        } fxn;
      bool val = false;

      if (nextarg ("<"))
        fxn = less_than;
      else if (nextarg ("<="))
        fxn = less_equal;
      else if (nextarg ("=") || nextarg ("=="))
        fxn = equal;
      else if (nextarg ("!="))
        fxn = not_equal;
      else if (nextarg (">="))
        fxn = greater_equal;
      else if (nextarg (">"))
        fxn = greater_than;
      else
        return l;
      r = eval3 (evaluate);

      if (evaluate)
        {
          int cmp;
          tostring (l);
          tostring (r);

          if (looks_like_integer (l->u.s) && looks_like_integer (r->u.s))
            cmp = strintcmp (l->u.s, r->u.s);
          else
            {
              errno = 0;
              cmp = strcoll (l->u.s, r->u.s);

              if (errno)
                {
                  error (0, errno, _("string comparison failed"));
                  error (0, 0, _("set LC_ALL='C' to work around the problem"));
                  die (EXPR_INVALID, 0,
                       _("the strings compared were %s and %s"),
                       quotearg_n_style (0, locale_quoting_style, l->u.s),
                       quotearg_n_style (1, locale_quoting_style, r->u.s));
                }
            }

          switch (fxn)
            {
            case less_than:     val = (cmp <  0); break;
            case less_equal:    val = (cmp <= 0); break;
            case equal:         val = (cmp == 0); break;
            case not_equal:     val = (cmp != 0); break;
            case greater_equal: val = (cmp >= 0); break;
            case greater_than:  val = (cmp >  0); break;
            default: abort ();
            }
        }

      freev (l);
      freev (r);
      l = int_value (val);
    }
}

/* Handle &.  */

static VALUE *
eval1 (bool evaluate)
{
  VALUE *l;
  VALUE *r;

#ifdef EVAL_TRACE
  trace ("eval1");
#endif
  l = eval2 (evaluate);
  while (1)
    {
      if (nextarg ("&"))
        {
          r = eval2 (evaluate && !null (l));
          if (null (l) || null (r))
            {
              freev (l);
              freev (r);
              l = int_value (0);
            }
          else
            freev (r);
        }
      else
        return l;
    }
}

/* Handle |.  */

static VALUE *
eval (bool evaluate)
{
  VALUE *l;
  VALUE *r;

#ifdef EVAL_TRACE
  trace ("eval");
#endif
  l = eval1 (evaluate);
  while (1)
    {
      if (nextarg ("|"))
        {
          r = eval1 (evaluate && null (l));
          if (null (l))
            {
              freev (l);
              l = r;
              if (null (l))
                {
                  freev (l);
                  l = int_value (0);
                }
            }
          else
            freev (r);
        }
      else
        return l;
    }
}
