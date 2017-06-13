/* modechange.c -- file mode manipulation

   Copyright (C) 1989-1990, 1997-1999, 2001, 2003-2006, 2009-2017 Free Software
   Foundation, Inc.

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

/* Written by David MacKenzie <djm@ai.mit.edu> */

/* The ASCII mode string is compiled into an array of 'struct
   modechange', which can then be applied to each file to be changed.
   We do this instead of re-parsing the ASCII string for each file
   because the compiled form requires less computation to use; when
   changing the mode of many files, this probably results in a
   performance gain.  */

#include "config.h"

#include "modechange.h"
#include "sys/stat.h"
#include "stat-macros.h"
#include "xalloc.h"
#include <stdlib.h>

/* The traditional octal values corresponding to each mode bit.  */
#define SUID 04000
#define SGID 02000
#define SVTX 01000
#define RUSR 00400
#define WUSR 00200
#define XUSR 00100
#define RGRP 00040
#define WGRP 00020
#define XGRP 00010
#define ROTH 00004
#define WOTH 00002
#define XOTH 00001
#define ALLM 07777 /* all octal mode bits */

/* Convert OCTAL, which uses one of the traditional octal values, to
   an internal mode_t value.  */
static mode_t
octal_to_mode (unsigned int octal)
{
  /* Help the compiler optimize the usual case where mode_t uses
     the traditional octal representation.  */
  return ((S_ISUID == SUID && S_ISGID == SGID && S_ISVTX == SVTX
           && S_IRUSR == RUSR && S_IWUSR == WUSR && S_IXUSR == XUSR
           && S_IRGRP == RGRP && S_IWGRP == WGRP && S_IXGRP == XGRP
           && S_IROTH == ROTH && S_IWOTH == WOTH && S_IXOTH == XOTH)
          ? octal
          : (mode_t) ((octal & SUID ? S_ISUID : 0)
                      | (octal & SGID ? S_ISGID : 0)
                      | (octal & SVTX ? S_ISVTX : 0)
                      | (octal & RUSR ? S_IRUSR : 0)
                      | (octal & WUSR ? S_IWUSR : 0)
                      | (octal & XUSR ? S_IXUSR : 0)
                      | (octal & RGRP ? S_IRGRP : 0)
                      | (octal & WGRP ? S_IWGRP : 0)
                      | (octal & XGRP ? S_IXGRP : 0)
                      | (octal & ROTH ? S_IROTH : 0)
                      | (octal & WOTH ? S_IWOTH : 0)
                      | (octal & XOTH ? S_IXOTH : 0)));
}

/* Special operations flags.  */
enum
  {
    /* For the sentinel at the end of the mode changes array.  */
    MODE_DONE,

    /* The typical case.  */
    MODE_ORDINARY_CHANGE,

    /* In addition to the typical case, affect the execute bits if at
       least one execute bit is set already, or if the file is a
       directory.  */
    MODE_X_IF_ANY_X,

    /* Instead of the typical case, copy some existing permissions for
       u, g, or o onto the other two.  Which of u, g, or o is copied
       is determined by which bits are set in the 'value' field.  */
    MODE_COPY_EXISTING
  };

/* Description of a mode change.  */
struct mode_change
{
  char op;                      /* One of "=+-".  */
  char flag;                    /* Special operations flag.  */
  mode_t affected;              /* Set for u, g, o, or a.  */
  mode_t value;                 /* Bits to add/remove.  */
  mode_t mentioned;             /* Bits explicitly mentioned.  */
};

/* Return a mode_change array with the specified "=ddd"-style
   mode change operation, where NEW_MODE is "ddd" and MENTIONED
   contains the bits explicitly mentioned in the mode are MENTIONED.  */

static struct mode_change *
make_node_op_equals (mode_t new_mode, mode_t mentioned)
{
  struct mode_change *p = xmalloc (2 * sizeof *p);
  p->op = '=';
  p->flag = MODE_ORDINARY_CHANGE;
  p->affected = CHMOD_MODE_BITS;
  p->value = new_mode;
  p->mentioned = mentioned;
  p[1].flag = MODE_DONE;
  return p;
}

/* Return a pointer to an array of file mode change operations created from
   MODE_STRING, an ASCII string that contains either an octal number
   specifying an absolute mode, or symbolic mode change operations with
   the form:
   [ugoa...][[+-=][rwxXstugo...]...][,...]

   Return NULL if 'mode_string' does not contain a valid
   representation of file mode change operations.  */

struct mode_change *
mode_compile (char const *mode_string)
{
  /* The array of mode-change directives to be returned.  */
  struct mode_change *mc;
  size_t used = 0;
  char const *p;

  if ('0' <= *mode_string && *mode_string < '8')
    {
      unsigned int octal_mode = 0;
      mode_t mode;
      mode_t mentioned;

      p = mode_string;
      do
        {
          octal_mode = 8 * octal_mode + *p++ - '0';
          if (ALLM < octal_mode)
            return NULL;
        }
      while ('0' <= *p && *p < '8');

      if (*p)
        return NULL;

      mode = octal_to_mode (octal_mode);
      mentioned = (p - mode_string < 5
                   ? (mode & (S_ISUID | S_ISGID)) | S_ISVTX | S_IRWXUGO
                   : CHMOD_MODE_BITS);
      return make_node_op_equals (mode, mentioned);
    }

  /* Allocate enough space to hold the result.  */
  {
    size_t needed = 1;
    for (p = mode_string; *p; p++)
      needed += (*p == '=' || *p == '+' || *p == '-');
    mc = xnmalloc (needed, sizeof *mc);
  }

  /* One loop iteration for each
     '[ugoa]*([-+=]([rwxXst]*|[ugo]))+|[-+=][0-7]+'.  */
  for (p = mode_string; ; p++)
    {
      /* Which bits in the mode are operated on.  */
      mode_t affected = 0;

      /* Turn on all the bits in 'affected' for each group given.  */
      for (;; p++)
        switch (*p)
          {
          default:
            goto invalid;
          case 'u':
            affected |= S_ISUID | S_IRWXU;
            break;
          case 'g':
            affected |= S_ISGID | S_IRWXG;
            break;
          case 'o':
            affected |= S_ISVTX | S_IRWXO;
            break;
          case 'a':
            affected |= CHMOD_MODE_BITS;
            break;
          case '=': case '+': case '-':
            goto no_more_affected;
          }
    no_more_affected:;

      do
        {
          char op = *p++;
          mode_t value;
          mode_t mentioned = 0;
          char flag = MODE_COPY_EXISTING;
          struct mode_change *change;

          switch (*p)
            {
            case '0': case '1': case '2': case '3':
            case '4': case '5': case '6': case '7':
              {
                unsigned int octal_mode = 0;

                do
                  {
                    octal_mode = 8 * octal_mode + *p++ - '0';
                    if (ALLM < octal_mode)
                      goto invalid;
                  }
                while ('0' <= *p && *p < '8');

                if (affected || (*p && *p != ','))
                  goto invalid;
                affected = mentioned = CHMOD_MODE_BITS;
                value = octal_to_mode (octal_mode);
                flag = MODE_ORDINARY_CHANGE;
                break;
              }

            case 'u':
              /* Set the affected bits to the value of the "u" bits
                 on the same file.  */
              value = S_IRWXU;
              p++;
              break;
            case 'g':
              /* Set the affected bits to the value of the "g" bits
                 on the same file.  */
              value = S_IRWXG;
              p++;
              break;
            case 'o':
              /* Set the affected bits to the value of the "o" bits
                 on the same file.  */
              value = S_IRWXO;
              p++;
              break;

            default:
              value = 0;
              flag = MODE_ORDINARY_CHANGE;

              for (;; p++)
                switch (*p)
                  {
                  case 'r':
                    value |= S_IRUSR | S_IRGRP | S_IROTH;
                    break;
                  case 'w':
                    value |= S_IWUSR | S_IWGRP | S_IWOTH;
                    break;
                  case 'x':
                    value |= S_IXUSR | S_IXGRP | S_IXOTH;
                    break;
                  case 'X':
                    flag = MODE_X_IF_ANY_X;
                    break;
                  case 's':
                    /* Set the setuid/gid bits if 'u' or 'g' is selected.  */
                    value |= S_ISUID | S_ISGID;
                    break;
                  case 't':
                    /* Set the "save text image" bit if 'o' is selected.  */
                    value |= S_ISVTX;
                    break;
                  default:
                    goto no_more_values;
                  }
            no_more_values:;
            }

          change = &mc[used++];
          change->op = op;
          change->flag = flag;
          change->affected = affected;
          change->value = value;
          change->mentioned =
            (mentioned ? mentioned : affected ? affected & value : value);
        }
      while (*p == '=' || *p == '+' || *p == '-');

      if (*p != ',')
        break;
    }

  if (*p == 0)
    {
      mc[used].flag = MODE_DONE;
      return mc;
    }

invalid:
  free (mc);
  return NULL;
}

/* Return a file mode change operation that sets permissions to match those
   of REF_FILE.  Return NULL (setting errno) if REF_FILE can't be accessed.  */

struct mode_change *
mode_create_from_ref (const char *ref_file)
{
  struct stat ref_stats;

  if (stat (ref_file, &ref_stats) != 0)
    return NULL;
  return make_node_op_equals (ref_stats.st_mode, CHMOD_MODE_BITS);
}

/* Return the file mode bits of OLDMODE (which is the mode of a
   directory if DIR), assuming the umask is UMASK_VALUE, adjusted as
   indicated by the list of change operations CHANGES.  If DIR, the
   type 'X' change affects the returned value even if no execute bits
   were set in OLDMODE, and set user and group ID bits are preserved
   unless CHANGES mentioned them.  If PMODE_BITS is not null, store into
   *PMODE_BITS a mask denoting file mode bits that are affected by
   CHANGES.

   The returned value and *PMODE_BITS contain only file mode bits.
   For example, they have the S_IFMT bits cleared on a standard
   Unix-like host.  */

mode_t
mode_adjust (mode_t oldmode, bool dir, mode_t umask_value,
             struct mode_change const *changes, mode_t *pmode_bits)
{
  /* The adjusted mode.  */
  mode_t newmode = oldmode & CHMOD_MODE_BITS;

  /* File mode bits that CHANGES cares about.  */
  mode_t mode_bits = 0;

  for (; changes->flag != MODE_DONE; changes++)
    {
      mode_t affected = changes->affected;
      mode_t omit_change =
        (dir ? S_ISUID | S_ISGID : 0) & ~ changes->mentioned;
      mode_t value = changes->value;

      switch (changes->flag)
        {
        case MODE_ORDINARY_CHANGE:
          break;

        case MODE_COPY_EXISTING:
          /* Isolate in 'value' the bits in 'newmode' to copy.  */
          value &= newmode;

          /* Copy the isolated bits to the other two parts.  */
          value |= ((value & (S_IRUSR | S_IRGRP | S_IROTH)
                     ? S_IRUSR | S_IRGRP | S_IROTH : 0)
                    | (value & (S_IWUSR | S_IWGRP | S_IWOTH)
                       ? S_IWUSR | S_IWGRP | S_IWOTH : 0)
                    | (value & (S_IXUSR | S_IXGRP | S_IXOTH)
                       ? S_IXUSR | S_IXGRP | S_IXOTH : 0));
          break;

        case MODE_X_IF_ANY_X:
          /* Affect the execute bits if execute bits are already set
             or if the file is a directory.  */
          if ((newmode & (S_IXUSR | S_IXGRP | S_IXOTH)) | dir)
            value |= S_IXUSR | S_IXGRP | S_IXOTH;
          break;
        }

      /* If WHO was specified, limit the change to the affected bits.
         Otherwise, apply the umask.  Either way, omit changes as
         requested.  */
      value &= (affected ? affected : ~umask_value) & ~ omit_change;

      switch (changes->op)
        {
        case '=':
          /* If WHO was specified, preserve the previous values of
             bits that are not affected by this change operation.
             Otherwise, clear all the bits.  */
          {
            mode_t preserved = (affected ? ~affected : 0) | omit_change;
            mode_bits |= CHMOD_MODE_BITS & ~preserved;
            newmode = (newmode & preserved) | value;
            break;
          }

        case '+':
          mode_bits |= value;
          newmode |= value;
          break;

        case '-':
          mode_bits |= value;
          newmode &= ~value;
          break;
        }
    }

  if (pmode_bits)
    *pmode_bits = mode_bits;
  return newmode;
}
