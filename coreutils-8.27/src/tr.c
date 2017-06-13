/* tr -- a filter to translate characters
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
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* Written by Jim Meyering */

#include <config.h>

#include <stdio.h>
#include <assert.h>
#include <sys/types.h>
#include <getopt.h>

#include "system.h"
#include "die.h"
#include "error.h"
#include "fadvise.h"
#include "quote.h"
#include "safe-read.h"
#include "xbinary-io.h"
#include "xstrtol.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "tr"

#define AUTHORS proper_name ("Jim Meyering")

enum { N_CHARS = UCHAR_MAX + 1 };

/* An unsigned integer type big enough to hold a repeat count or an
   unsigned character.  POSIX requires support for repeat counts as
   high as 2**31 - 1.  Since repeat counts might need to expand to
   match the length of an argument string, we need at least size_t to
   avoid arbitrary internal limits.  It doesn't cost much to use
   uintmax_t, though.  */
typedef uintmax_t count;

/* The value for Spec_list->state that indicates to
   get_next that it should initialize the tail pointer.
   Its value should be as large as possible to avoid conflict
   a valid value for the state field -- and that may be as
   large as any valid repeat_count.  */
#define BEGIN_STATE (UINTMAX_MAX - 1)

/* The value for Spec_list->state that indicates to
   get_next that the element pointed to by Spec_list->tail is
   being considered for the first time on this pass through the
   list -- it indicates that get_next should make any necessary
   initializations.  */
#define NEW_ELEMENT (BEGIN_STATE + 1)

/* The maximum possible repeat count.  Due to how the states are
   implemented, it can be as much as BEGIN_STATE.  */
#define REPEAT_COUNT_MAXIMUM BEGIN_STATE

/* The following (but not CC_NO_CLASS) are indices into the array of
   valid character class strings.  */
enum Char_class
  {
    CC_ALNUM = 0, CC_ALPHA = 1, CC_BLANK = 2, CC_CNTRL = 3,
    CC_DIGIT = 4, CC_GRAPH = 5, CC_LOWER = 6, CC_PRINT = 7,
    CC_PUNCT = 8, CC_SPACE = 9, CC_UPPER = 10, CC_XDIGIT = 11,
    CC_NO_CLASS = 9999
  };

/* Character class to which a character (returned by get_next) belonged;
   but it is set only if the construct from which the character was obtained
   was one of the character classes [:upper:] or [:lower:].  The value
   is used only when translating and then, only to make sure that upper
   and lower class constructs have the same relative positions in string1
   and string2.  */
enum Upper_Lower_class
  {
    UL_LOWER,
    UL_UPPER,
    UL_NONE
  };

/* The type of a List_element.  See build_spec_list for more details.  */
enum Range_element_type
  {
    RE_NORMAL_CHAR,
    RE_RANGE,
    RE_CHAR_CLASS,
    RE_EQUIV_CLASS,
    RE_REPEATED_CHAR
  };

/* One construct in one of tr's argument strings.
   For example, consider the POSIX version of the classic tr command:
       tr -cs 'a-zA-Z_' '[\n*]'
   String1 has 3 constructs, two of which are ranges (a-z and A-Z),
   and a single normal character, '_'.  String2 has one construct.  */
struct List_element
  {
    enum Range_element_type type;
    struct List_element *next;
    union
      {
        unsigned char normal_char;
        struct			/* unnamed */
          {
            unsigned char first_char;
            unsigned char last_char;
          }
        range;
        enum Char_class char_class;
        unsigned char equiv_code;
        struct			/* unnamed */
          {
            unsigned char the_repeated_char;
            count repeat_count;
          }
        repeated_char;
      }
    u;
  };

/* Each of tr's argument strings is parsed into a form that is easier
   to work with: a linked list of constructs (struct List_element).
   Each Spec_list structure also encapsulates various attributes of
   the corresponding argument string.  The attributes are used mainly
   to verify that the strings are valid in the context of any options
   specified (like -s, -d, or -c).  The main exception is the member
   'tail', which is first used to construct the list.  After construction,
   it is used by get_next to save its state when traversing the list.
   The member 'state' serves a similar function.  */
struct Spec_list
  {
    /* Points to the head of the list of range elements.
       The first struct is a dummy; its members are never used.  */
    struct List_element *head;

    /* When appending, points to the last element.  When traversing via
       get_next(), points to the element to process next.  Setting
       Spec_list.state to the value BEGIN_STATE before calling get_next
       signals get_next to initialize tail to point to head->next.  */
    struct List_element *tail;

    /* Used to save state between calls to get_next.  */
    count state;

    /* Length, in the sense that length ('a-z[:digit:]123abc')
       is 42 ( = 26 + 10 + 6).  */
    count length;

    /* The number of [c*] and [c*0] constructs that appear in this spec.  */
    size_t n_indefinite_repeats;

    /* If n_indefinite_repeats is nonzero, this points to the List_element
       corresponding to the last [c*] or [c*0] construct encountered in
       this spec.  Otherwise it is undefined.  */
    struct List_element *indefinite_repeat_element;

    /* True if this spec contains at least one equivalence
       class construct e.g. [=c=].  */
    bool has_equiv_class;

    /* True if this spec contains at least one character class
       construct.  E.g. [:digit:].  */
    bool has_char_class;

    /* True if this spec contains at least one of the character class
       constructs (all but upper and lower) that aren't allowed in s2.  */
    bool has_restricted_char_class;
  };

/* A representation for escaped string1 or string2.  As a string is parsed,
   any backslash-escaped characters (other than octal or \a, \b, \f, \n,
   etc.) are marked as such in this structure by setting the corresponding
   entry in the ESCAPED vector.  */
struct E_string
{
  char *s;
  bool *escaped;
  size_t len;
};

/* Return nonzero if the Ith character of escaped string ES matches C
   and is not escaped itself.  */
static inline bool
es_match (struct E_string const *es, size_t i, char c)
{
  return es->s[i] == c && !es->escaped[i];
}

/* When true, each sequence in the input of a repeated character
   (call it c) is replaced (in the output) by a single occurrence of c
   for every c in the squeeze set.  */
static bool squeeze_repeats = false;

/* When true, removes characters in the delete set from input.  */
static bool delete = false;

/* Use the complement of set1 in place of set1.  */
static bool complement = false;

/* When tr is performing translation and string1 is longer than string2,
   POSIX says that the result is unspecified.  That gives the implementor
   of a POSIX conforming version of tr two reasonable choices for the
   semantics of this case.

   * The BSD tr pads string2 to the length of string1 by
   repeating the last character in string2.

   * System V tr ignores characters in string1 that have no
   corresponding character in string2.  That is, string1 is effectively
   truncated to the length of string2.

   When nonzero, this flag causes GNU tr to imitate the behavior
   of System V tr when translating with string1 longer than string2.
   The default is to emulate BSD tr.  This flag is ignored in modes where
   no translation is performed.  Emulating the System V tr
   in this exceptional case causes the relatively common BSD idiom:

       tr -cs A-Za-z0-9 '\012'

   to break (it would convert only zero bytes, rather than all
   non-alphanumerics, to newlines).

   WARNING: This switch does not provide general BSD or System V
   compatibility.  For example, it doesn't disable the interpretation
   of the POSIX constructs [:alpha:], [=c=], and [c*10], so if by
   some unfortunate coincidence you use such constructs in scripts
   expecting to use some other version of tr, the scripts will break.  */
static bool truncate_set1 = false;

/* An alias for (!delete && non_option_args == 2).
   It is set in main and used there and in validate().  */
static bool translating;

static char io_buf[BUFSIZ];

static char const *const char_class_name[] =
{
  "alnum", "alpha", "blank", "cntrl", "digit", "graph",
  "lower", "print", "punct", "space", "upper", "xdigit"
};

/* Array of boolean values.  A character 'c' is a member of the
   squeeze set if and only if in_squeeze_set[c] is true.  The squeeze
   set is defined by the last (possibly, the only) string argument
   on the command line when the squeeze option is given.  */
static bool in_squeeze_set[N_CHARS];

/* Array of boolean values.  A character 'c' is a member of the
   delete set if and only if in_delete_set[c] is true.  The delete
   set is defined by the first (or only) string argument on the
   command line when the delete option is given.  */
static bool in_delete_set[N_CHARS];

/* Array of character values defining the translation (if any) that
   tr is to perform.  Translation is performed only when there are
   two specification strings and the delete switch is not given.  */
static char xlate[N_CHARS];

static struct option const long_options[] =
{
  {"complement", no_argument, NULL, 'c'},
  {"delete", no_argument, NULL, 'd'},
  {"squeeze-repeats", no_argument, NULL, 's'},
  {"truncate-set1", no_argument, NULL, 't'},
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
      printf (_("\
Usage: %s [OPTION]... SET1 [SET2]\n\
"),
              program_name);
      fputs (_("\
Translate, squeeze, and/or delete characters from standard input,\n\
writing to standard output.\n\
\n\
  -c, -C, --complement    use the complement of SET1\n\
  -d, --delete            delete characters in SET1, do not translate\n\
  -s, --squeeze-repeats   replace each sequence of a repeated character\n\
                            that is listed in the last specified SET,\n\
                            with a single occurrence of that character\n\
  -t, --truncate-set1     first truncate SET1 to length of SET2\n\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      fputs (_("\
\n\
SETs are specified as strings of characters.  Most represent themselves.\n\
Interpreted sequences are:\n\
\n\
  \\NNN            character with octal value NNN (1 to 3 octal digits)\n\
  \\\\              backslash\n\
  \\a              audible BEL\n\
  \\b              backspace\n\
  \\f              form feed\n\
  \\n              new line\n\
  \\r              return\n\
  \\t              horizontal tab\n\
"), stdout);
     fputs (_("\
  \\v              vertical tab\n\
  CHAR1-CHAR2     all characters from CHAR1 to CHAR2 in ascending order\n\
  [CHAR*]         in SET2, copies of CHAR until length of SET1\n\
  [CHAR*REPEAT]   REPEAT copies of CHAR, REPEAT octal if starting with 0\n\
  [:alnum:]       all letters and digits\n\
  [:alpha:]       all letters\n\
  [:blank:]       all horizontal whitespace\n\
  [:cntrl:]       all control characters\n\
  [:digit:]       all digits\n\
"), stdout);
     fputs (_("\
  [:graph:]       all printable characters, not including space\n\
  [:lower:]       all lower case letters\n\
  [:print:]       all printable characters, including space\n\
  [:punct:]       all punctuation characters\n\
  [:space:]       all horizontal or vertical whitespace\n\
  [:upper:]       all upper case letters\n\
  [:xdigit:]      all hexadecimal digits\n\
  [=CHAR=]        all characters which are equivalent to CHAR\n\
"), stdout);
     fputs (_("\
\n\
Translation occurs if -d is not given and both SET1 and SET2 appear.\n\
-t may be used only when translating.  SET2 is extended to length of\n\
SET1 by repeating its last character as necessary.  Excess characters\n\
of SET2 are ignored.  Only [:lower:] and [:upper:] are guaranteed to\n\
expand in ascending order; used in SET2 while translating, they may\n\
only be used in pairs to specify case conversion.  -s uses the last\n\
specified SET, and occurs after translation or deletion.\n\
"), stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

/* Return nonzero if the character C is a member of the
   equivalence class containing the character EQUIV_CLASS.  */

static inline bool
is_equiv_class_member (unsigned char equiv_class, unsigned char c)
{
  return (equiv_class == c);
}

/* Return true if the character C is a member of the
   character class CHAR_CLASS.  */

static bool _GL_ATTRIBUTE_PURE
is_char_class_member (enum Char_class char_class, unsigned char c)
{
  int result;

  switch (char_class)
    {
    case CC_ALNUM:
      result = isalnum (c);
      break;
    case CC_ALPHA:
      result = isalpha (c);
      break;
    case CC_BLANK:
      result = isblank (c);
      break;
    case CC_CNTRL:
      result = iscntrl (c);
      break;
    case CC_DIGIT:
      result = isdigit (c);
      break;
    case CC_GRAPH:
      result = isgraph (c);
      break;
    case CC_LOWER:
      result = islower (c);
      break;
    case CC_PRINT:
      result = isprint (c);
      break;
    case CC_PUNCT:
      result = ispunct (c);
      break;
    case CC_SPACE:
      result = isspace (c);
      break;
    case CC_UPPER:
      result = isupper (c);
      break;
    case CC_XDIGIT:
      result = isxdigit (c);
      break;
    default:
      abort ();
    }

  return !! result;
}

static void
es_free (struct E_string *es)
{
  free (es->s);
  free (es->escaped);
}

/* Perform the first pass over each range-spec argument S, converting all
   \c and \ddd escapes to their one-byte representations.  If an invalid
   quote sequence is found print an error message and return false;
   Otherwise set *ES to the resulting string and return true.
   The resulting array of characters may contain zero-bytes;
   however, on input, S is assumed to be null-terminated, and hence
   cannot contain actual (non-escaped) zero bytes.  */

static bool
unquote (char const *s, struct E_string *es)
{
  size_t len = strlen (s);

  es->s = xmalloc (len);
  es->escaped = xcalloc (len, sizeof es->escaped[0]);

  unsigned int j = 0;
  for (unsigned int i = 0; s[i]; i++)
    {
      unsigned char c;
      int oct_digit;

      switch (s[i])
        {
        case '\\':
          es->escaped[j] = true;
          switch (s[i + 1])
            {
            case '\\':
              c = '\\';
              break;
            case 'a':
              c = '\a';
              break;
            case 'b':
              c = '\b';
              break;
            case 'f':
              c = '\f';
              break;
            case 'n':
              c = '\n';
              break;
            case 'r':
              c = '\r';
              break;
            case 't':
              c = '\t';
              break;
            case 'v':
              c = '\v';
              break;
            case '0':
            case '1':
            case '2':
            case '3':
            case '4':
            case '5':
            case '6':
            case '7':
              c = s[i + 1] - '0';
              oct_digit = s[i + 2] - '0';
              if (0 <= oct_digit && oct_digit <= 7)
                {
                  c = 8 * c + oct_digit;
                  ++i;
                  oct_digit = s[i + 2] - '0';
                  if (0 <= oct_digit && oct_digit <= 7)
                    {
                      if (8 * c + oct_digit < N_CHARS)
                        {
                          c = 8 * c + oct_digit;
                          ++i;
                        }
                      else
                        {
                          /* A 3-digit octal number larger than \377 won't
                             fit in 8 bits.  So we stop when adding the
                             next digit would put us over the limit and
                             give a warning about the ambiguity.  POSIX
                             isn't clear on this, and we interpret this
                             lack of clarity as meaning the resulting behavior
                             is undefined, which means we're allowed to issue
                             a warning.  */
                          error (0, 0, _("warning: the ambiguous octal escape\
 \\%c%c%c is being\n\tinterpreted as the 2-byte sequence \\0%c%c, %c"),
                                 s[i], s[i + 1], s[i + 2],
                                 s[i], s[i + 1], s[i + 2]);
                        }
                    }
                }
              break;
            case '\0':
              error (0, 0, _("warning: an unescaped backslash "
                             "at end of string is not portable"));
              /* POSIX is not clear about this.  */
              es->escaped[j] = false;
              i--;
              c = '\\';
              break;
            default:
              c = s[i + 1];
              break;
            }
          ++i;
          es->s[j++] = c;
          break;
        default:
          es->s[j++] = s[i];
          break;
        }
    }
  es->len = j;
  return true;
}

/* If CLASS_STR is a valid character class string, return its index
   in the global char_class_name array.  Otherwise, return CC_NO_CLASS.  */

static enum Char_class _GL_ATTRIBUTE_PURE
look_up_char_class (char const *class_str, size_t len)
{
  enum Char_class i;

  for (i = 0; i < ARRAY_CARDINALITY (char_class_name); i++)
    if (STREQ_LEN (class_str, char_class_name[i], len)
        && strlen (char_class_name[i]) == len)
      return i;
  return CC_NO_CLASS;
}

/* Return a newly allocated string with a printable version of C.
   This function is used solely for formatting error messages.  */

static char *
make_printable_char (unsigned char c)
{
  char *buf = xmalloc (5);

  if (isprint (c))
    {
      buf[0] = c;
      buf[1] = '\0';
    }
  else
    {
      sprintf (buf, "\\%03o", c);
    }
  return buf;
}

/* Return a newly allocated copy of S which is suitable for printing.
   LEN is the number of characters in S.  Most non-printing
   (isprint) characters are represented by a backslash followed by
   3 octal digits.  However, the characters represented by \c escapes
   where c is one of [abfnrtv] are represented by their 2-character \c
   sequences.  This function is used solely for printing error messages.  */

static char *
make_printable_str (char const *s, size_t len)
{
  /* Worst case is that every character expands to a backslash
     followed by a 3-character octal escape sequence.  */
  char *printable_buf = xnmalloc (len + 1, 4);
  char *p = printable_buf;

  for (size_t i = 0; i < len; i++)
    {
      char buf[5];
      char const *tmp = NULL;
      unsigned char c = s[i];

      switch (c)
        {
        case '\\':
          tmp = "\\";
          break;
        case '\a':
          tmp = "\\a";
          break;
        case '\b':
          tmp = "\\b";
          break;
        case '\f':
          tmp = "\\f";
          break;
        case '\n':
          tmp = "\\n";
          break;
        case '\r':
          tmp = "\\r";
          break;
        case '\t':
          tmp = "\\t";
          break;
        case '\v':
          tmp = "\\v";
          break;
        default:
          if (isprint (c))
            {
              buf[0] = c;
              buf[1] = '\0';
            }
          else
            sprintf (buf, "\\%03o", c);
          tmp = buf;
          break;
        }
      p = stpcpy (p, tmp);
    }
  return printable_buf;
}

/* Append a newly allocated structure representing a
   character C to the specification list LIST.  */

static void
append_normal_char (struct Spec_list *list, unsigned char c)
{
  struct List_element *new = xmalloc (sizeof *new);
  new->next = NULL;
  new->type = RE_NORMAL_CHAR;
  new->u.normal_char = c;
  assert (list->tail);
  list->tail->next = new;
  list->tail = new;
}

/* Append a newly allocated structure representing the range
   of characters from FIRST to LAST to the specification list LIST.
   Return false if LAST precedes FIRST in the collating sequence,
   true otherwise.  This means that '[c-c]' is acceptable.  */

static bool
append_range (struct Spec_list *list, unsigned char first, unsigned char last)
{
  if (last < first)
    {
      char *tmp1 = make_printable_char (first);
      char *tmp2 = make_printable_char (last);

      error (0, 0,
       _("range-endpoints of '%s-%s' are in reverse collating sequence order"),
             tmp1, tmp2);
      free (tmp1);
      free (tmp2);
      return false;
    }
  struct List_element *new = xmalloc (sizeof *new);
  new->next = NULL;
  new->type = RE_RANGE;
  new->u.range.first_char = first;
  new->u.range.last_char = last;
  assert (list->tail);
  list->tail->next = new;
  list->tail = new;
  return true;
}

/* If CHAR_CLASS_STR is a valid character class string, append a
   newly allocated structure representing that character class to the end
   of the specification list LIST and return true.  If CHAR_CLASS_STR is not
   a valid string return false.  */

static bool
append_char_class (struct Spec_list *list,
                   char const *char_class_str, size_t len)
{
  enum Char_class char_class = look_up_char_class (char_class_str, len);
  if (char_class == CC_NO_CLASS)
    return false;
  struct List_element *new = xmalloc (sizeof *new);
  new->next = NULL;
  new->type = RE_CHAR_CLASS;
  new->u.char_class = char_class;
  assert (list->tail);
  list->tail->next = new;
  list->tail = new;
  return true;
}

/* Append a newly allocated structure representing a [c*n]
   repeated character construct to the specification list LIST.
   THE_CHAR is the single character to be repeated, and REPEAT_COUNT
   is a non-negative repeat count.  */

static void
append_repeated_char (struct Spec_list *list, unsigned char the_char,
                      count repeat_count)
{
  struct List_element *new = xmalloc (sizeof *new);
  new->next = NULL;
  new->type = RE_REPEATED_CHAR;
  new->u.repeated_char.the_repeated_char = the_char;
  new->u.repeated_char.repeat_count = repeat_count;
  assert (list->tail);
  list->tail->next = new;
  list->tail = new;
}

/* Given a string, EQUIV_CLASS_STR, from a [=str=] context and
   the length of that string, LEN, if LEN is exactly one, append
   a newly allocated structure representing the specified
   equivalence class to the specification list, LIST and return true.
   If LEN is not 1, return false.  */

static bool
append_equiv_class (struct Spec_list *list,
                    char const *equiv_class_str, size_t len)
{
  if (len != 1)
    return false;

  struct List_element *new = xmalloc (sizeof *new);
  new->next = NULL;
  new->type = RE_EQUIV_CLASS;
  new->u.equiv_code = *equiv_class_str;
  assert (list->tail);
  list->tail->next = new;
  list->tail = new;
  return true;
}

/* Search forward starting at START_IDX for the 2-char sequence
   (PRE_BRACKET_CHAR,']') in the string P of length P_LEN.  If such
   a sequence is found, set *RESULT_IDX to the index of the first
   character and return true.  Otherwise return false.  P may contain
   zero bytes.  */

static bool
find_closing_delim (const struct E_string *es, size_t start_idx,
                    char pre_bracket_char, size_t *result_idx)
{
  for (size_t i = start_idx; i < es->len - 1; i++)
    if (es->s[i] == pre_bracket_char && es->s[i + 1] == ']'
        && !es->escaped[i] && !es->escaped[i + 1])
      {
        *result_idx = i;
        return true;
      }
  return false;
}

/* Parse the bracketed repeat-char syntax.  If the P_LEN characters
   beginning with P[ START_IDX ] comprise a valid [c*n] construct,
   then set *CHAR_TO_REPEAT, *REPEAT_COUNT, and *CLOSING_BRACKET_IDX
   and return zero. If the second character following
   the opening bracket is not '*' or if no closing bracket can be
   found, return -1.  If a closing bracket is found and the
   second char is '*', but the string between the '*' and ']' isn't
   empty, an octal number, or a decimal number, print an error message
   and return -2.  */

static int
find_bracketed_repeat (const struct E_string *es, size_t start_idx,
                       unsigned char *char_to_repeat, count *repeat_count,
                       size_t *closing_bracket_idx)
{
  assert (start_idx + 1 < es->len);
  if (!es_match (es, start_idx + 1, '*'))
    return -1;

  for (size_t i = start_idx + 2; i < es->len && !es->escaped[i]; i++)
    {
      if (es->s[i] == ']')
        {
          size_t digit_str_len = i - start_idx - 2;

          *char_to_repeat = es->s[start_idx];
          if (digit_str_len == 0)
            {
              /* We've matched [c*] -- no explicit repeat count.  */
              *repeat_count = 0;
            }
          else
            {
              /* Here, we have found [c*s] where s should be a string
                 of octal (if it starts with '0') or decimal digits.  */
              char const *digit_str = &es->s[start_idx + 2];
              char *d_end;
              if ((xstrtoumax (digit_str, &d_end, *digit_str == '0' ? 8 : 10,
                               repeat_count, NULL)
                   != LONGINT_OK)
                  || REPEAT_COUNT_MAXIMUM < *repeat_count
                  || digit_str + digit_str_len != d_end)
                {
                  char *tmp = make_printable_str (digit_str, digit_str_len);
                  error (0, 0,
                         _("invalid repeat count %s in [c*n] construct"),
                         quote (tmp));
                  free (tmp);
                  return -2;
                }
            }
          *closing_bracket_idx = i;
          return 0;
        }
    }
  return -1;			/* No bracket found.  */
}

/* Return true if the string at ES->s[IDX] matches the regular
   expression '\*[0-9]*\]', false otherwise.  The string does not
   match if any of its characters are escaped.  */

static bool _GL_ATTRIBUTE_PURE
star_digits_closebracket (const struct E_string *es, size_t idx)
{
  if (!es_match (es, idx, '*'))
    return false;

  for (size_t i = idx + 1; i < es->len; i++)
    if (!ISDIGIT (to_uchar (es->s[i])) || es->escaped[i])
      return es_match (es, i, ']');
  return false;
}

/* Convert string UNESCAPED_STRING (which has been preprocessed to
   convert backslash-escape sequences) of length LEN characters into
   a linked list of the following 5 types of constructs:
      - [:str:] Character class where 'str' is one of the 12 valid strings.
      - [=c=] Equivalence class where 'c' is any single character.
      - [c*n] Repeat the single character 'c' 'n' times. n may be omitted.
          However, if 'n' is present, it must be a non-negative octal or
          decimal integer.
      - r-s Range of characters from 'r' to 's'.  The second endpoint must
          not precede the first in the current collating sequence.
      - c Any other character is interpreted as itself.  */

static bool
build_spec_list (const struct E_string *es, struct Spec_list *result)
{
  char const *p = es->s;

  /* The main for-loop below recognizes the 4 multi-character constructs.
     A character that matches (in its context) none of the multi-character
     constructs is classified as 'normal'.  Since all multi-character
     constructs have at least 3 characters, any strings of length 2 or
     less are composed solely of normal characters.  Hence, the index of
     the outer for-loop runs only as far as LEN-2.  */
  size_t i;
  for (i = 0; i + 2 < es->len; /* empty */)
    {
      if (es_match (es, i, '['))
        {
          bool matched_multi_char_construct;
          size_t closing_bracket_idx;
          unsigned char char_to_repeat;
          count repeat_count;
          int err;

          matched_multi_char_construct = true;
          if (es_match (es, i + 1, ':') || es_match (es, i + 1, '='))
            {
              size_t closing_delim_idx;

              if (find_closing_delim (es, i + 2, p[i + 1], &closing_delim_idx))
                {
                  size_t opnd_str_len = closing_delim_idx - 1 - (i + 2) + 1;
                  char const *opnd_str = p + i + 2;

                  if (opnd_str_len == 0)
                    {
                      if (p[i + 1] == ':')
                        error (0, 0, _("missing character class name '[::]'"));
                      else
                        error (0, 0,
                               _("missing equivalence class character '[==]'"));
                      return false;
                    }

                  if (p[i + 1] == ':')
                    {
                      /* FIXME: big comment.  */
                      if (!append_char_class (result, opnd_str, opnd_str_len))
                        {
                          if (star_digits_closebracket (es, i + 2))
                            goto try_bracketed_repeat;
                          else
                            {
                              char *tmp = make_printable_str (opnd_str,
                                                              opnd_str_len);
                              error (0, 0, _("invalid character class %s"),
                                     quote (tmp));
                              free (tmp);
                              return false;
                            }
                        }
                    }
                  else
                    {
                      /* FIXME: big comment.  */
                      if (!append_equiv_class (result, opnd_str, opnd_str_len))
                        {
                          if (star_digits_closebracket (es, i + 2))
                            goto try_bracketed_repeat;
                          else
                            {
                              char *tmp = make_printable_str (opnd_str,
                                                              opnd_str_len);
                              error (0, 0,
               _("%s: equivalence class operand must be a single character"),
                                     tmp);
                              free (tmp);
                              return false;
                            }
                        }
                    }

                  i = closing_delim_idx + 2;
                  continue;
                }
              /* Else fall through.  This could be [:*] or [=*].  */
            }

        try_bracketed_repeat:

          /* Determine whether this is a bracketed repeat range
             matching the RE \[.\*(dec_or_oct_number)?\].  */
          err = find_bracketed_repeat (es, i + 1, &char_to_repeat,
                                       &repeat_count,
                                       &closing_bracket_idx);
          if (err == 0)
            {
              append_repeated_char (result, char_to_repeat, repeat_count);
              i = closing_bracket_idx + 1;
            }
          else if (err == -1)
            {
              matched_multi_char_construct = false;
            }
          else
            {
              /* Found a string that looked like [c*n] but the
                 numeric part was invalid.  */
              return false;
            }

          if (matched_multi_char_construct)
            continue;

          /* We reach this point if P does not match [:str:], [=c=],
             [c*n], or [c*].  Now, see if P looks like a range '[-c'
             (from '[' to 'c').  */
        }

      /* Look ahead one char for ranges like a-z.  */
      if (es_match (es, i + 1, '-'))
        {
          if (!append_range (result, p[i], p[i + 2]))
            return false;
          i += 3;
        }
      else
        {
          append_normal_char (result, p[i]);
          ++i;
        }
    }

  /* Now handle the (2 or fewer) remaining characters p[i]..p[es->len - 1].  */
  for (; i < es->len; i++)
    append_normal_char (result, p[i]);

  return true;
}

/* Advance past the current construct.
   S->tail must be non-NULL.  */
static void
skip_construct (struct Spec_list *s)
{
  s->tail = s->tail->next;
  s->state = NEW_ELEMENT;
}

/* Given a Spec_list S (with its saved state implicit in the values
   of its members 'tail' and 'state'), return the next single character
   in the expansion of S's constructs.  If the last character of S was
   returned on the previous call or if S was empty, this function
   returns -1.  For example, successive calls to get_next where S
   represents the spec-string 'a-d[y*3]' will return the sequence
   of values a, b, c, d, y, y, y, -1.  Finally, if the construct from
   which the returned character comes is [:upper:] or [:lower:], the
   parameter CLASS is given a value to indicate which it was.  Otherwise
   CLASS is set to UL_NONE.  This value is used only when constructing
   the translation table to verify that any occurrences of upper and
   lower class constructs in the spec-strings appear in the same relative
   positions.  */

static int
get_next (struct Spec_list *s, enum Upper_Lower_class *class)
{
  struct List_element *p;
  int return_val;
  int i;

  if (class)
    *class = UL_NONE;

  if (s->state == BEGIN_STATE)
    {
      s->tail = s->head->next;
      s->state = NEW_ELEMENT;
    }

  p = s->tail;
  if (p == NULL)
    return -1;

  switch (p->type)
    {
    case RE_NORMAL_CHAR:
      return_val = p->u.normal_char;
      s->state = NEW_ELEMENT;
      s->tail = p->next;
      break;

    case RE_RANGE:
      if (s->state == NEW_ELEMENT)
        s->state = p->u.range.first_char;
      else
        ++(s->state);
      return_val = s->state;
      if (s->state == p->u.range.last_char)
        {
          s->tail = p->next;
          s->state = NEW_ELEMENT;
        }
      break;

    case RE_CHAR_CLASS:
      if (class)
        {
          switch (p->u.char_class)
            {
            case CC_LOWER:
              *class = UL_LOWER;
              break;
            case CC_UPPER:
              *class = UL_UPPER;
              break;
            default:
              break;
            }
        }

      if (s->state == NEW_ELEMENT)
        {
          for (i = 0; i < N_CHARS; i++)
            if (is_char_class_member (p->u.char_class, i))
              break;
          assert (i < N_CHARS);
          s->state = i;
        }
      assert (is_char_class_member (p->u.char_class, s->state));
      return_val = s->state;
      for (i = s->state + 1; i < N_CHARS; i++)
        if (is_char_class_member (p->u.char_class, i))
          break;
      if (i < N_CHARS)
        s->state = i;
      else
        {
          s->tail = p->next;
          s->state = NEW_ELEMENT;
        }
      break;

    case RE_EQUIV_CLASS:
      /* FIXME: this assumes that each character is alone in its own
         equivalence class (which appears to be correct for my
         LC_COLLATE.  But I don't know of any function that allows
         one to determine a character's equivalence class.  */

      return_val = p->u.equiv_code;
      s->state = NEW_ELEMENT;
      s->tail = p->next;
      break;

    case RE_REPEATED_CHAR:
      /* Here, a repeat count of n == 0 means don't repeat at all.  */
      if (p->u.repeated_char.repeat_count == 0)
        {
          s->tail = p->next;
          s->state = NEW_ELEMENT;
          return_val = get_next (s, class);
        }
      else
        {
          if (s->state == NEW_ELEMENT)
            {
              s->state = 0;
            }
          ++(s->state);
          return_val = p->u.repeated_char.the_repeated_char;
          if (s->state == p->u.repeated_char.repeat_count)
            {
              s->tail = p->next;
              s->state = NEW_ELEMENT;
            }
        }
      break;

    default:
      abort ();
    }

  return return_val;
}

/* This is a minor kludge.  This function is called from
   get_spec_stats to determine the cardinality of a set derived
   from a complemented string.  It's a kludge in that some of the
   same operations are (duplicated) performed in set_initialize.  */

static int
card_of_complement (struct Spec_list *s)
{
  int c;
  int cardinality = N_CHARS;
  bool in_set[N_CHARS] = { 0, };

  s->state = BEGIN_STATE;
  while ((c = get_next (s, NULL)) != -1)
    {
      cardinality -= (!in_set[c]);
      in_set[c] = true;
    }
  return cardinality;
}

/* Discard the lengths associated with a case conversion,
   as using the actual number of upper or lower case characters
   is problematic when they don't match in some locales.
   Also ensure the case conversion classes in string2 are
   aligned correctly with those in string1.
   Note POSIX says the behavior of 'tr "[:upper:]" "[:upper:]"'
   is undefined.  Therefore we allow it (unlike Solaris)
   and treat it as a no-op.  */

static void
validate_case_classes (struct Spec_list *s1, struct Spec_list *s2)
{
  size_t n_upper = 0;
  size_t n_lower = 0;
  unsigned int i;
  int c1 = 0;
  int c2 = 0;
  count old_s1_len = s1->length;
  count old_s2_len = s2->length;
  struct List_element *s1_tail = s1->tail;
  struct List_element *s2_tail = s2->tail;
  bool s1_new_element = true;
  bool s2_new_element = true;

  if (!s2->has_char_class)
    return;

  for (i = 0; i < N_CHARS; i++)
    {
      if (isupper (i))
        n_upper++;
      if (islower (i))
        n_lower++;
    }

  s1->state = BEGIN_STATE;
  s2->state = BEGIN_STATE;

  while (c1 != -1 && c2 != -1)
    {
      enum Upper_Lower_class class_s1, class_s2;

      c1 = get_next (s1, &class_s1);
      c2 = get_next (s2, &class_s2);

      /* If c2 transitions to a new case class, then
         c1 must also transition at the same time.  */
      if (s2_new_element && class_s2 != UL_NONE
          && !(s1_new_element && class_s1 != UL_NONE))
        die (EXIT_FAILURE, 0,
             _("misaligned [:upper:] and/or [:lower:] construct"));

      /* If case converting, quickly skip over the elements.  */
      if (class_s2 != UL_NONE)
        {
          skip_construct (s1);
          skip_construct (s2);
          /* Discount insignificant/problematic lengths.  */
          s1->length -= (class_s1 == UL_UPPER ? n_upper : n_lower) - 1;
          s2->length -= (class_s2 == UL_UPPER ? n_upper : n_lower) - 1;
        }

      s1_new_element = s1->state == NEW_ELEMENT; /* Next element is new.  */
      s2_new_element = s2->state == NEW_ELEMENT; /* Next element is new.  */
    }

  assert (old_s1_len >= s1->length && old_s2_len >= s2->length);

  s1->tail = s1_tail;
  s2->tail = s2_tail;
}

/* Gather statistics about the spec-list S in preparation for the tests
   in validate that determine the consistency of the specs.  This function
   is called at most twice; once for string1, and again for any string2.
   LEN_S1 < 0 indicates that this is the first call and that S represents
   string1.  When LEN_S1 >= 0, it is the length of the expansion of the
   constructs in string1, and we can use its value to resolve any
   indefinite repeat construct in S (which represents string2).  Hence,
   this function has the side-effect that it converts a valid [c*]
   construct in string2 to [c*n] where n is large enough (or 0) to give
   string2 the same length as string1.  For example, with the command
   tr a-z 'A[\n*]Z' on the second call to get_spec_stats, LEN_S1 would
   be 26 and S (representing string2) would be converted to 'A[\n*24]Z'.  */

static void
get_spec_stats (struct Spec_list *s)
{
  struct List_element *p;
  count length = 0;

  s->n_indefinite_repeats = 0;
  s->has_equiv_class = false;
  s->has_restricted_char_class = false;
  s->has_char_class = false;
  for (p = s->head->next; p; p = p->next)
    {
      count len = 0;
      count new_length;

      switch (p->type)
        {
        case RE_NORMAL_CHAR:
          len = 1;
          break;

        case RE_RANGE:
          assert (p->u.range.last_char >= p->u.range.first_char);
          len = p->u.range.last_char - p->u.range.first_char + 1;
          break;

        case RE_CHAR_CLASS:
          s->has_char_class = true;
          for (int i = 0; i < N_CHARS; i++)
            if (is_char_class_member (p->u.char_class, i))
              ++len;
          switch (p->u.char_class)
            {
            case CC_UPPER:
            case CC_LOWER:
              break;
            default:
              s->has_restricted_char_class = true;
              break;
            }
          break;

        case RE_EQUIV_CLASS:
          for (int i = 0; i < N_CHARS; i++)
            if (is_equiv_class_member (p->u.equiv_code, i))
              ++len;
          s->has_equiv_class = true;
          break;

        case RE_REPEATED_CHAR:
          if (p->u.repeated_char.repeat_count > 0)
            len = p->u.repeated_char.repeat_count;
          else
            {
              s->indefinite_repeat_element = p;
              ++(s->n_indefinite_repeats);
            }
          break;

        default:
          abort ();
        }

      /* Check for arithmetic overflow in computing length.  Also, reject
         any length greater than the maximum repeat count, in case the
         length is later used to compute the repeat count for an
         indefinite element.  */
      new_length = length + len;
      if (! (length <= new_length && new_length <= REPEAT_COUNT_MAXIMUM))
        die (EXIT_FAILURE, 0, _("too many characters in set"));
      length = new_length;
    }

  s->length = length;
}

static void
get_s1_spec_stats (struct Spec_list *s1)
{
  get_spec_stats (s1);
  if (complement)
    s1->length = card_of_complement (s1);
}

static void
get_s2_spec_stats (struct Spec_list *s2, count len_s1)
{
  get_spec_stats (s2);
  if (len_s1 >= s2->length && s2->n_indefinite_repeats == 1)
    {
      s2->indefinite_repeat_element->u.repeated_char.repeat_count =
        len_s1 - s2->length;
      s2->length = len_s1;
    }
}

static void
spec_init (struct Spec_list *spec_list)
{
  struct List_element *new = xmalloc (sizeof *new);
  spec_list->head = spec_list->tail = new;
  spec_list->head->next = NULL;
}

/* This function makes two passes over the argument string S.  The first
   one converts all \c and \ddd escapes to their one-byte representations.
   The second constructs a linked specification list, SPEC_LIST, of the
   characters and constructs that comprise the argument string.  If either
   of these passes detects an error, this function returns false.  */

static bool
parse_str (char const *s, struct Spec_list *spec_list)
{
  struct E_string es;
  bool ok = unquote (s, &es) && build_spec_list (&es, spec_list);
  es_free (&es);
  return ok;
}

/* Given two specification lists, S1 and S2, and assuming that
   S1->length > S2->length, append a single [c*n] element to S2 where c
   is the last character in the expansion of S2 and n is the difference
   between the two lengths.
   Upon successful completion, S2->length is set to S1->length.  The only
   way this function can fail to make S2 as long as S1 is when S2 has
   zero-length, since in that case, there is no last character to repeat.
   So S2->length is required to be at least 1.  */

static void
string2_extend (const struct Spec_list *s1, struct Spec_list *s2)
{
  struct List_element *p;
  unsigned char char_to_repeat;

  assert (translating);
  assert (s1->length > s2->length);
  assert (s2->length > 0);

  p = s2->tail;
  switch (p->type)
    {
    case RE_NORMAL_CHAR:
      char_to_repeat = p->u.normal_char;
      break;
    case RE_RANGE:
      char_to_repeat = p->u.range.last_char;
      break;
    case RE_CHAR_CLASS:
      /* Note BSD allows extending of classes in string2.  For example:
           tr '[:upper:]0-9' '[:lower:]'
         That's not portable however, contradicts POSIX and is dependent
         on your collating sequence.  */
      die (EXIT_FAILURE, 0,
           _("when translating with string1 longer than string2,\nthe\
 latter string must not end with a character class"));

    case RE_REPEATED_CHAR:
      char_to_repeat = p->u.repeated_char.the_repeated_char;
      break;

    case RE_EQUIV_CLASS:
      /* This shouldn't happen, because validate exits with an error
         if it finds an equiv class in string2 when translating.  */
      abort ();

    default:
      abort ();
    }

  append_repeated_char (s2, char_to_repeat, s1->length - s2->length);
  s2->length = s1->length;
}

/* Return true if S is a non-empty list in which exactly one
   character (but potentially, many instances of it) appears.
   E.g., [X*] or xxxxxxxx.  */

static bool
homogeneous_spec_list (struct Spec_list *s)
{
  int b, c;

  s->state = BEGIN_STATE;

  if ((b = get_next (s, NULL)) == -1)
    return false;

  while ((c = get_next (s, NULL)) != -1)
    if (c != b)
      return false;

  return true;
}

/* Die with an error message if S1 and S2 describe strings that
   are not valid with the given command line switches.
   A side effect of this function is that if a valid [c*] or
   [c*0] construct appears in string2, it is converted to [c*n]
   with a value for n that makes s2->length == s1->length.  By
   the same token, if the --truncate-set1 option is not
   given, S2 may be extended.  */

static void
validate (struct Spec_list *s1, struct Spec_list *s2)
{
  get_s1_spec_stats (s1);
  if (s1->n_indefinite_repeats > 0)
    {
      die (EXIT_FAILURE, 0,
           _("the [c*] repeat construct may not appear in string1"));
    }

  if (s2)
    {
      get_s2_spec_stats (s2, s1->length);

      if (s2->n_indefinite_repeats > 1)
        {
          die (EXIT_FAILURE, 0,
               _("only one [c*] repeat construct may appear in string2"));
        }

      if (translating)
        {
          if (s2->has_equiv_class)
            {
              die (EXIT_FAILURE, 0,
                   _("[=c=] expressions may not appear in string2\
 when translating"));
            }

          if (s2->has_restricted_char_class)
            {
              die (EXIT_FAILURE, 0,
                   _("when translating, the only character classes that may\
 appear in\nstring2 are 'upper' and 'lower'"));
            }

          validate_case_classes (s1, s2);

          if (s1->length > s2->length)
            {
              if (!truncate_set1)
                {
                  /* string2 must be non-empty unless --truncate-set1 is
                     given or string1 is empty.  */

                  if (s2->length == 0)
                    die (EXIT_FAILURE, 0,
                     _("when not truncating set1, string2 must be non-empty"));
                  string2_extend (s1, s2);
                }
            }

          if (complement && s1->has_char_class
              && ! (s2->length == s1->length && homogeneous_spec_list (s2)))
            {
              die (EXIT_FAILURE, 0,
                   _("when translating with complemented character classes,\
\nstring2 must map all characters in the domain to one"));
            }
        }
      else
        /* Not translating.  */
        {
          if (s2->n_indefinite_repeats > 0)
            die (EXIT_FAILURE, 0,
                 _("the [c*] construct may appear in string2 only\
 when translating"));
        }
    }
}

/* Read buffers of SIZE bytes via the function READER (if READER is
   NULL, read from stdin) until EOF.  When non-NULL, READER is either
   read_and_delete or read_and_xlate.  After each buffer is read, it is
   processed and written to stdout.  The buffers are processed so that
   multiple consecutive occurrences of the same character in the input
   stream are replaced by a single occurrence of that character if the
   character is in the squeeze set.  */

static void
squeeze_filter (char *buf, size_t size, size_t (*reader) (char *, size_t))
{
  /* A value distinct from any character that may have been stored in a
     buffer as the result of a block-read in the function squeeze_filter.  */
  const int NOT_A_CHAR = INT_MAX;

  int char_to_squeeze = NOT_A_CHAR;
  size_t i = 0;
  size_t nr = 0;

  while (true)
    {
      if (i >= nr)
        {
          nr = reader (buf, size);
          if (nr == 0)
            break;
          i = 0;
        }

      size_t begin = i;

      if (char_to_squeeze == NOT_A_CHAR)
        {
          size_t out_len;
          /* Here, by being a little tricky, we can get a significant
             performance increase in most cases when the input is
             reasonably large.  Since tr will modify the input only
             if two consecutive (and identical) input characters are
             in the squeeze set, we can step by two through the data
             when searching for a character in the squeeze set.  This
             means there may be a little more work in a few cases and
             perhaps twice as much work in the worst cases where most
             of the input is removed by squeezing repeats.  But most
             uses of this functionality seem to remove less than 20-30%
             of the input.  */
          for (; i < nr && !in_squeeze_set[to_uchar (buf[i])]; i += 2)
            continue;

          /* There is a special case when i == nr and we've just
             skipped a character (the last one in buf) that is in
             the squeeze set.  */
          if (i == nr && in_squeeze_set[to_uchar (buf[i - 1])])
            --i;

          if (i >= nr)
            out_len = nr - begin;
          else
            {
              char_to_squeeze = buf[i];
              /* We're about to output buf[begin..i].  */
              out_len = i - begin + 1;

              /* But since we stepped by 2 in the loop above,
                 out_len may be one too large.  */
              if (i > 0 && buf[i - 1] == char_to_squeeze)
                --out_len;

              /* Advance i to the index of first character to be
                 considered when looking for a char different from
                 char_to_squeeze.  */
              ++i;
            }
          if (out_len > 0
              && fwrite (&buf[begin], 1, out_len, stdout) != out_len)
            die (EXIT_FAILURE, errno, _("write error"));
        }

      if (char_to_squeeze != NOT_A_CHAR)
        {
          /* Advance i to index of first char != char_to_squeeze
             (or to nr if all the rest of the characters in this
             buffer are the same as char_to_squeeze).  */
          for (; i < nr && buf[i] == char_to_squeeze; i++)
            continue;
          if (i < nr)
            char_to_squeeze = NOT_A_CHAR;
          /* If (i >= nr) we've squeezed the last character in this buffer.
             So now we have to read a new buffer and continue comparing
             characters against char_to_squeeze.  */
        }
    }
}

static size_t
plain_read (char *buf, size_t size)
{
  size_t nr = safe_read (STDIN_FILENO, buf, size);
  if (nr == SAFE_READ_ERROR)
    die (EXIT_FAILURE, errno, _("read error"));
  return nr;
}

/* Read buffers of SIZE bytes from stdin until one is found that
   contains at least one character not in the delete set.  Store
   in the array BUF, all characters from that buffer that are not
   in the delete set, and return the number of characters saved
   or 0 upon EOF.  */

static size_t
read_and_delete (char *buf, size_t size)
{
  size_t n_saved;

  /* This enclosing do-while loop is to make sure that
     we don't return zero (indicating EOF) when we've
     just deleted all the characters in a buffer.  */
  do
    {
      size_t nr = plain_read (buf, size);

      if (nr == 0)
        return 0;

      /* This first loop may be a waste of code, but gives much
         better performance when no characters are deleted in
         the beginning of a buffer.  It just avoids the copying
         of buf[i] into buf[n_saved] when it would be a NOP.  */

      size_t i;
      for (i = 0; i < nr && !in_delete_set[to_uchar (buf[i])]; i++)
        continue;
      n_saved = i;

      for (++i; i < nr; i++)
        if (!in_delete_set[to_uchar (buf[i])])
          buf[n_saved++] = buf[i];
    }
  while (n_saved == 0);

  return n_saved;
}

/* Read at most SIZE bytes from stdin into the array BUF.  Then
   perform the in-place and one-to-one mapping specified by the global
   array 'xlate'.  Return the number of characters read, or 0 upon EOF.  */

static size_t
read_and_xlate (char *buf, size_t size)
{
  size_t bytes_read = plain_read (buf, size);

  for (size_t i = 0; i < bytes_read; i++)
    buf[i] = xlate[to_uchar (buf[i])];

  return bytes_read;
}

/* Initialize a boolean membership set, IN_SET, with the character
   values obtained by traversing the linked list of constructs S
   using the function 'get_next'.  IN_SET is expected to have been
   initialized to all zeros by the caller.  If COMPLEMENT_THIS_SET
   is true the resulting set is complemented.  */

static void
set_initialize (struct Spec_list *s, bool complement_this_set, bool *in_set)
{
  int c;

  s->state = BEGIN_STATE;
  while ((c = get_next (s, NULL)) != -1)
    in_set[c] = true;
  if (complement_this_set)
    for (size_t i = 0; i < N_CHARS; i++)
      in_set[i] = (!in_set[i]);
}

int
main (int argc, char **argv)
{
  int c;
  int non_option_args;
  int min_operands;
  int max_operands;
  struct Spec_list buf1, buf2;
  struct Spec_list *s1 = &buf1;
  struct Spec_list *s2 = &buf2;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  while ((c = getopt_long (argc, argv, "+cCdst", long_options, NULL)) != -1)
    {
      switch (c)
        {
        case 'c':
        case 'C':
          complement = true;
          break;

        case 'd':
          delete = true;
          break;

        case 's':
          squeeze_repeats = true;
          break;

        case 't':
          truncate_set1 = true;
          break;

        case_GETOPT_HELP_CHAR;

        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);

        default:
          usage (EXIT_FAILURE);
          break;
        }
    }

  non_option_args = argc - optind;
  translating = (non_option_args == 2 && !delete);
  min_operands = 1 + (delete == squeeze_repeats);
  max_operands = 1 + (delete <= squeeze_repeats);

  if (non_option_args < min_operands)
    {
      if (non_option_args == 0)
        error (0, 0, _("missing operand"));
      else
        {
          error (0, 0, _("missing operand after %s"), quote (argv[argc - 1]));
          fprintf (stderr, "%s\n",
                   _(squeeze_repeats
                     ? N_("Two strings must be given when "
                          "both deleting and squeezing repeats.")
                     : N_("Two strings must be given when translating.")));
        }
      usage (EXIT_FAILURE);
    }

  if (max_operands < non_option_args)
    {
      error (0, 0, _("extra operand %s"), quote (argv[optind + max_operands]));
      if (non_option_args == 2)
        fprintf (stderr, "%s\n",
                 _("Only one string may be given when "
                   "deleting without squeezing repeats."));
      usage (EXIT_FAILURE);
    }

  spec_init (s1);
  if (!parse_str (argv[optind], s1))
    return EXIT_FAILURE;

  if (non_option_args == 2)
    {
      spec_init (s2);
      if (!parse_str (argv[optind + 1], s2))
        return EXIT_FAILURE;
    }
  else
    s2 = NULL;

  validate (s1, s2);

  /* Use binary I/O, since 'tr' is sometimes used to transliterate
     non-printable characters, or characters which are stripped away
     by text-mode reads (like CR and ^Z).  */
  xset_binary_mode (STDIN_FILENO, O_BINARY);
  xset_binary_mode (STDOUT_FILENO, O_BINARY);
  fadvise (stdin, FADVISE_SEQUENTIAL);

  if (squeeze_repeats && non_option_args == 1)
    {
      set_initialize (s1, complement, in_squeeze_set);
      squeeze_filter (io_buf, sizeof io_buf, plain_read);
    }
  else if (delete && non_option_args == 1)
    {
      set_initialize (s1, complement, in_delete_set);

      while (true)
        {
          size_t nr = read_and_delete (io_buf, sizeof io_buf);
          if (nr == 0)
            break;
          if (fwrite (io_buf, 1, nr, stdout) != nr)
            die (EXIT_FAILURE, errno, _("write error"));
        }
    }
  else if (squeeze_repeats && delete && non_option_args == 2)
    {
      set_initialize (s1, complement, in_delete_set);
      set_initialize (s2, false, in_squeeze_set);
      squeeze_filter (io_buf, sizeof io_buf, read_and_delete);
    }
  else if (translating)
    {
      if (complement)
        {
          bool *in_s1 = in_delete_set;

          set_initialize (s1, false, in_s1);
          s2->state = BEGIN_STATE;
          for (int i = 0; i < N_CHARS; i++)
            xlate[i] = i;
          for (int i = 0; i < N_CHARS; i++)
            {
              if (!in_s1[i])
                {
                  int ch = get_next (s2, NULL);
                  assert (ch != -1 || truncate_set1);
                  if (ch == -1)
                    {
                      /* This will happen when tr is invoked like e.g.
                         tr -cs A-Za-z0-9 '\012'.  */
                      break;
                    }
                  xlate[i] = ch;
                }
            }
        }
      else
        {
          int c1, c2;
          enum Upper_Lower_class class_s1;
          enum Upper_Lower_class class_s2;

          for (int i = 0; i < N_CHARS; i++)
            xlate[i] = i;
          s1->state = BEGIN_STATE;
          s2->state = BEGIN_STATE;
          while (true)
            {
              c1 = get_next (s1, &class_s1);
              c2 = get_next (s2, &class_s2);

              if (class_s1 == UL_LOWER && class_s2 == UL_UPPER)
                {
                  for (int i = 0; i < N_CHARS; i++)
                    if (islower (i))
                      xlate[i] = toupper (i);
                }
              else if (class_s1 == UL_UPPER && class_s2 == UL_LOWER)
                {
                  for (int i = 0; i < N_CHARS; i++)
                    if (isupper (i))
                      xlate[i] = tolower (i);
                }
              else
                {
                  /* The following should have been checked by validate...  */
                  if (c1 == -1 || c2 == -1)
                    break;
                  xlate[c1] = c2;
                }

              /* When case-converting, skip the elements as an optimization.  */
              if (class_s2 != UL_NONE)
                {
                  skip_construct (s1);
                  skip_construct (s2);
                }
            }
          assert (c1 == -1 || truncate_set1);
        }
      if (squeeze_repeats)
        {
          set_initialize (s2, false, in_squeeze_set);
          squeeze_filter (io_buf, sizeof io_buf, read_and_xlate);
        }
      else
        {
          while (true)
            {
              size_t bytes_read = read_and_xlate (io_buf, sizeof io_buf);
              if (bytes_read == 0)
                break;
              if (fwrite (io_buf, 1, bytes_read, stdout) != bytes_read)
                die (EXIT_FAILURE, errno, _("write error"));
            }
        }
    }

  if (close (STDIN_FILENO) != 0)
    die (EXIT_FAILURE, errno, _("standard input"));

  return EXIT_SUCCESS;
}
