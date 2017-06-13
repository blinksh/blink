/* set-fields.c -- common functions for parsing field list
   Copyright (C) 2015-2017 Free Software Foundation, Inc.

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

/* Extracted from cut.c by Assaf Gordon */

#include <config.h>

#include "system.h"
#include "error.h"
#include "quote.h"
#include "xstrndup.h"
#include "set-fields.h"

/* Array of `struct field_range_pair' holding all the finite ranges. */
struct field_range_pair *frp;

/* Number of finite ranges specified by the user. */
size_t n_frp;

/* Number of `struct field_range_pair's allocated. */
static size_t n_frp_allocated;

#define FATAL_ERROR(Message)                                            \
  do                                                                    \
    {                                                                   \
      error (0, 0, (Message));                                          \
      usage (EXIT_FAILURE);                                             \
    }                                                                   \
  while (0)

/* Append LOW, HIGH to the list RP of range pairs, allocating additional
   space if necessary.  Update global variable N_FRP.  When allocating,
   update global variable N_FRP_ALLOCATED.  */
static void
add_range_pair (size_t lo, size_t hi)
{
  if (n_frp == n_frp_allocated)
    frp = X2NREALLOC (frp, &n_frp_allocated);
  frp[n_frp].lo = lo;
  frp[n_frp].hi = hi;
  ++n_frp;
}


/* Comparison function for qsort to order the list of
   struct range_pairs.  */
static int
compare_ranges (const void *a, const void *b)
{
  int a_start = ((const struct field_range_pair *) a)->lo;
  int b_start = ((const struct field_range_pair *) b)->lo;
  return a_start < b_start ? -1 : a_start > b_start;
}

/* Reallocate Range Pair entries, with corresponding
   entries outside the range of each specified entry.  */

static void
complement_rp (void)
{
  struct field_range_pair *c = frp;
  size_t n = n_frp;
  size_t i;

  frp = NULL;
  n_frp = 0;
  n_frp_allocated = 0;

  if (c[0].lo > 1)
    add_range_pair (1, c[0].lo - 1);

  for (i = 1; i < n; ++i)
    {
      if (c[i-1].hi + 1 == c[i].lo)
        continue;

      add_range_pair (c[i-1].hi + 1, c[i].lo - 1);
    }

  if (c[n-1].hi < SIZE_MAX)
    add_range_pair (c[n-1].hi + 1, SIZE_MAX);

  free (c);
}

/* Given the list of field or byte range specifications FIELDSTR,
   allocate and initialize the FRP array. FIELDSTR should
   be composed of one or more numbers or ranges of numbers, separated
   by blanks or commas.  Incomplete ranges may be given: '-m' means '1-m';
   'n-' means 'n' through end of line.
   n=0 and n>=SIZE_MAX values will trigger an error.

   if SETFLD_ALLOW_DASH option is used, a single '-' means all fields
   (otherwise a single dash triggers an error).

   if SETFLD_COMPLEMENT option is used, the specified field list
   is complemented (e.g. '1-3' will result in fields '4-').

   if SETFLD_ERRMSG_USE_POS option is used, error messages
   will say 'position' (or 'byte/character positions')
   instead of fields (used with cut -b/-c).

   The function terminates on failure.

   Upon return, the FRP array is initialized to contain
   a non-overlapping, increasing list of field ranges.

   N_FRP holds the number of field ranges in the FRP array.

   The first field is stored as 1 (zero is not used).
   An open-ended range (i.e., until the last field of the input line)
   is indicated with hi = SIZE_MAX.

   A sentinel of SIZE_MAX/SIZE_MAX is always added as the last
   field range pair.

   Examples:
   given '1-2,4', frp = [ { .lo = 1,        .hi = 2 },
                          { .lo = 4,        .hi = 4 },
                          { .lo = SIZE_MAX, .hi = SIZE_MAX } ];

   given '3-',    frp = [ { .lo = 3,        .hi = SIZE_MAX },
                          { .lo = SIZE_MAX, .hi = SIZE_MAX } ];
*/
void
set_fields (const char *fieldstr, unsigned int options)
{
  size_t initial = 1;		/* Value of first number in a range.  */
  size_t value = 0;		/* If nonzero, a number being accumulated.  */
  bool lhs_specified = false;
  bool rhs_specified = false;
  bool dash_found = false;	/* True if a '-' is found in this field.  */

  size_t i;
  bool in_digits = false;

  /* Collect and store in RP the range end points. */

  /* Special case: '--field=-' means all fields, emulate '--field=1-' . */
  if ((options & SETFLD_ALLOW_DASH) && STREQ (fieldstr,"-"))
    {
      value = 1;
      lhs_specified = true;
      dash_found = true;
      fieldstr++;
    }

  while (true)
    {
      if (*fieldstr == '-')
        {
          in_digits = false;
          /* Starting a range. */
          if (dash_found)
            FATAL_ERROR ( (options & SETFLD_ERRMSG_USE_POS)
                          ?_("invalid byte or character range")
                          :_("invalid field range"));

          dash_found = true;
          fieldstr++;

          if (lhs_specified && !value)
            FATAL_ERROR ( (options & SETFLD_ERRMSG_USE_POS)
                          ?_("byte/character positions are numbered from 1")
                          :_("fields are numbered from 1"));

          initial = (lhs_specified ? value : 1);
          value = 0;
        }
      else if (*fieldstr == ','
               || isblank (to_uchar (*fieldstr)) || *fieldstr == '\0')
        {
          in_digits = false;
          /* Ending the string, or this field/byte sublist. */
          if (dash_found)
            {
              dash_found = false;

              if (!lhs_specified && !rhs_specified)
                {
                  /* if a lone dash is allowed, emulate '1-' for all fields */
                  if (options & SETFLD_ALLOW_DASH)
                    initial = 1;
                  else
                    FATAL_ERROR (_("invalid range with no endpoint: -"));
                }

              /* A range.  Possibilities: -n, m-n, n-.
                 In any case, 'initial' contains the start of the range. */
              if (!rhs_specified)
                {
                  /* 'n-'.  From 'initial' to end of line. */
                  add_range_pair (initial, SIZE_MAX);
                }
              else
                {
                  /* 'm-n' or '-n' (1-n). */
                  if (value < initial)
                    FATAL_ERROR (_("invalid decreasing range"));

                  add_range_pair (initial, value);
                }
              value = 0;
            }
          else
            {
              /* A simple field number, not a range. */
              if (value == 0)
                FATAL_ERROR ( (options & SETFLD_ERRMSG_USE_POS)
                              ?_("byte/character positions are numbered from 1")
                              :_("fields are numbered from 1"));

              add_range_pair (value, value);
              value = 0;
            }

          if (*fieldstr == '\0')
            break;

          fieldstr++;
          lhs_specified = false;
          rhs_specified = false;
        }
      else if (ISDIGIT (*fieldstr))
        {
          /* Record beginning of digit string, in case we have to
             complain about it.  */
          static char const *num_start;
          if (!in_digits || !num_start)
            num_start = fieldstr;
          in_digits = true;

          if (dash_found)
            rhs_specified = 1;
          else
            lhs_specified = 1;

          /* Detect overflow.  */
          if (!DECIMAL_DIGIT_ACCUMULATE (value, *fieldstr - '0', size_t)
              || value == SIZE_MAX)
            {
              /* In case the user specified -c$(echo 2^64|bc),22,
                 complain only about the first number.  */
              /* Determine the length of the offending number.  */
              size_t len = strspn (num_start, "0123456789");
              char *bad_num = xstrndup (num_start, len);
              error (0, 0, (options & SETFLD_ERRMSG_USE_POS)
                           ?_("byte/character offset %s is too large")
                           :_("field number %s is too large"),
                           quote (bad_num));
              free (bad_num);
              usage (EXIT_FAILURE);
            }

          fieldstr++;
        }
      else
        {
          error (0, 0, (options & SETFLD_ERRMSG_USE_POS)
                       ?_("invalid byte/character position %s")
                       :_("invalid field value %s"),
                       quote (fieldstr));
          usage (EXIT_FAILURE);
        }
    }

  if (!n_frp)
    FATAL_ERROR ( (options&SETFLD_ERRMSG_USE_POS)
                  ?_("missing list of byte/character positions")
                  :_("missing list of fields"));

  qsort (frp, n_frp, sizeof (frp[0]), compare_ranges);

  /* Merge range pairs (e.g. `2-5,3-4' becomes `2-5'). */
  for (i = 0; i < n_frp; ++i)
    {
      for (size_t j = i + 1; j < n_frp; ++j)
        {
          if (frp[j].lo <= frp[i].hi)
            {
              frp[i].hi = MAX (frp[j].hi, frp[i].hi);
              memmove (frp + j, frp + j + 1, (n_frp - j - 1) * sizeof *frp);
              n_frp--;
              j--;
            }
          else
            break;
        }
    }

  if (options & SETFLD_COMPLEMENT)
    complement_rp ();

  /* After merging, reallocate RP so we release memory to the system.
     Also add a sentinel at the end of RP, to avoid out of bounds access
     and for performance reasons.  */
  ++n_frp;
  frp = xrealloc (frp, n_frp * sizeof (struct field_range_pair));
  frp[n_frp - 1].lo = frp[n_frp - 1].hi = SIZE_MAX;
}

void
reset_fields (void)
{
  n_frp = 0 ;
  n_frp_allocated = 0;
  free (frp);
  frp = NULL;
}
