/* df - summarize free disk space
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

/* Written by David MacKenzie <djm@gnu.ai.mit.edu>.
   --human-readable option added by lm@sgi.com.
   --si and large file support added by eggert@twinsun.com.  */

#include <config.h>
#include <stdio.h>
#include <sys/types.h>
#include <getopt.h>
#include <assert.h>

#include "system.h"
#include "canonicalize.h"
#include "die.h"
#include "error.h"
#include "fsusage.h"
#include "human.h"
#include "mbsalign.h"
#include "mbswidth.h"
#include "mountlist.h"
#include "quote.h"
#include "find-mount-point.h"
#include "hash.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "df"

#undef usage
#define usage df_usage
static void df_usage (int status);

#define AUTHORS \
  proper_name ("Torbjorn Granlund"), \
  proper_name ("David MacKenzie"), \
  proper_name ("Paul Eggert")

struct devlist
{
  dev_t dev_num;
  struct mount_entry *me;
  struct devlist *next;
};

/* Filled with device numbers of examined file systems to avoid
   duplicates in output.  */
static Hash_table *devlist_table;

/* If true, show even file systems with zero size or
   uninteresting types.  */
static bool show_all_fs;

/* If true, show only local file systems.  */
static bool show_local_fs;

/* If true, output data for each file system corresponding to a
   command line argument -- even if it's a dummy (automounter) entry.  */
static bool show_listed_fs;

/* Human-readable options for output.  */
static int human_output_opts;

/* The units to use when printing sizes.  */
static uintmax_t output_block_size;

/* True if a file system has been processed for output.  */
static bool file_systems_processed;

/* If true, invoke the 'sync' system call before getting any usage data.
   Using this option can make df very slow, especially with many or very
   busy disks.  Note that this may make a difference on some systems --
   SunOS 4.1.3, for one.  It is *not* necessary on GNU/Linux.  */
static bool require_sync;

/* Desired exit status.  */
static int exit_status;

/* A file system type to display.  */

struct fs_type_list
{
  char *fs_name;
  struct fs_type_list *fs_next;
};

/* Linked list of file system types to display.
   If 'fs_select_list' is NULL, list all types.
   This table is generated dynamically from command-line options,
   rather than hardcoding into the program what it thinks are the
   valid file system types; let the user specify any file system type
   they want to, and if there are any file systems of that type, they
   will be shown.

   Some file system types:
   4.2 4.3 ufs nfs swap ignore io vm efs dbg */

static struct fs_type_list *fs_select_list;

/* Linked list of file system types to omit.
   If the list is empty, don't exclude any types.  */

static struct fs_type_list *fs_exclude_list;

/* Linked list of mounted file systems.  */
static struct mount_entry *mount_list;

/* If true, print file system type as well.  */
static bool print_type;

/* If true, print a grand total at the end.  */
static bool print_grand_total;

/* Grand total data.  */
static struct fs_usage grand_fsu;

/* Display modes.  */
enum
{
  DEFAULT_MODE,
  INODES_MODE,
  HUMAN_MODE,
  POSIX_MODE,
  OUTPUT_MODE
};
static int header_mode = DEFAULT_MODE;

/* Displayable fields.  */
typedef enum
{
  SOURCE_FIELD, /* file system */
  FSTYPE_FIELD, /* FS type */
  SIZE_FIELD,   /* FS size */
  USED_FIELD,   /* FS size used  */
  AVAIL_FIELD,  /* FS size available */
  PCENT_FIELD,  /* percent used */
  ITOTAL_FIELD, /* inode total */
  IUSED_FIELD,  /* inodes used */
  IAVAIL_FIELD, /* inodes available */
  IPCENT_FIELD, /* inodes used in percent */
  TARGET_FIELD, /* mount point */
  FILE_FIELD,   /* specified file name */
  INVALID_FIELD /* validation marker */
} display_field_t;

/* Flag if a field contains a block, an inode or another value.  */
typedef enum
{
  BLOCK_FLD, /* Block values field */
  INODE_FLD, /* Inode values field */
  OTHER_FLD  /* Neutral field, e.g. target */
} field_type_t;

/* Attributes of a display field.  */
struct field_data_t
{
  display_field_t field;
  char const *arg;
  field_type_t field_type;
  const char *caption;/* NULL means to use the default header of this field.  */
  size_t width;       /* Auto adjusted (up) widths used to align columns.  */
  mbs_align_t align;  /* Alignment for this field.  */
  bool used;
};

/* Header strings, minimum width and alignment for the above fields.  */
static struct field_data_t field_data[] = {
  [SOURCE_FIELD] = { SOURCE_FIELD,
    "source", OTHER_FLD, N_("Filesystem"), 14, MBS_ALIGN_LEFT,  false },

  [FSTYPE_FIELD] = { FSTYPE_FIELD,
    "fstype", OTHER_FLD, N_("Type"),        4, MBS_ALIGN_LEFT,  false },

  [SIZE_FIELD] = { SIZE_FIELD,
    "size",   BLOCK_FLD, N_("blocks"),      5, MBS_ALIGN_RIGHT, false },

  [USED_FIELD] = { USED_FIELD,
    "used",   BLOCK_FLD, N_("Used"),        5, MBS_ALIGN_RIGHT, false },

  [AVAIL_FIELD] = { AVAIL_FIELD,
    "avail",  BLOCK_FLD, N_("Available"),   5, MBS_ALIGN_RIGHT, false },

  [PCENT_FIELD] = { PCENT_FIELD,
    "pcent",  BLOCK_FLD, N_("Use%"),        4, MBS_ALIGN_RIGHT, false },

  [ITOTAL_FIELD] = { ITOTAL_FIELD,
    "itotal", INODE_FLD, N_("Inodes"),      5, MBS_ALIGN_RIGHT, false },

  [IUSED_FIELD] = { IUSED_FIELD,
    "iused",  INODE_FLD, N_("IUsed"),       5, MBS_ALIGN_RIGHT, false },

  [IAVAIL_FIELD] = { IAVAIL_FIELD,
    "iavail", INODE_FLD, N_("IFree"),       5, MBS_ALIGN_RIGHT, false },

  [IPCENT_FIELD] = { IPCENT_FIELD,
    "ipcent", INODE_FLD, N_("IUse%"),       4, MBS_ALIGN_RIGHT, false },

  [TARGET_FIELD] = { TARGET_FIELD,
    "target", OTHER_FLD, N_("Mounted on"),  0, MBS_ALIGN_LEFT,  false },

  [FILE_FIELD] = { FILE_FIELD,
    "file",   OTHER_FLD, N_("File"),        0, MBS_ALIGN_LEFT,  false }
};

static char const *all_args_string =
  "source,fstype,itotal,iused,iavail,ipcent,size,"
  "used,avail,pcent,file,target";

/* Storage for the definition of output columns.  */
static struct field_data_t **columns;

/* The current number of output columns.  */
static size_t ncolumns;

/* Field values.  */
struct field_values_t
{
  uintmax_t input_units;
  uintmax_t output_units;
  uintmax_t total;
  uintmax_t available;
  bool negate_available;
  uintmax_t available_to_root;
  uintmax_t used;
  bool negate_used;
};

/* Storage for pointers for each string (cell of table).  */
static char ***table;

/* The current number of processed rows (including header).  */
static size_t nrows;

/* For long options that have no equivalent short option, use a
   non-character as a pseudo short option, starting with CHAR_MAX + 1.  */
enum
{
  NO_SYNC_OPTION = CHAR_MAX + 1,
  SYNC_OPTION,
  TOTAL_OPTION,
  OUTPUT_OPTION
};

static struct option const long_options[] =
{
  {"all", no_argument, NULL, 'a'},
  {"block-size", required_argument, NULL, 'B'},
  {"inodes", no_argument, NULL, 'i'},
  {"human-readable", no_argument, NULL, 'h'},
  {"si", no_argument, NULL, 'H'},
  {"local", no_argument, NULL, 'l'},
  {"output", optional_argument, NULL, OUTPUT_OPTION},
  {"portability", no_argument, NULL, 'P'},
  {"print-type", no_argument, NULL, 'T'},
  {"sync", no_argument, NULL, SYNC_OPTION},
  {"no-sync", no_argument, NULL, NO_SYNC_OPTION},
  {"total", no_argument, NULL, TOTAL_OPTION},
  {"type", required_argument, NULL, 't'},
  {"exclude-type", required_argument, NULL, 'x'},
  {GETOPT_HELP_OPTION_DECL},
  {GETOPT_VERSION_OPTION_DECL},
  {NULL, 0, NULL, 0}
};

/* Replace problematic chars with '?'.
   Since only control characters are currently considered,
   this should work in all encodings.  */

static char*
hide_problematic_chars (char *cell)
{
  char *p = cell;
  while (*p)
    {
      if (iscntrl (to_uchar (*p)))
        *p = '?';
      p++;
    }
  return cell;
}

/* Dynamically allocate a row of pointers in TABLE, which
   can then be accessed with standard 2D array notation.  */

static void
alloc_table_row (void)
{
  nrows++;
  table = xnrealloc (table, nrows, sizeof (char **));
  table[nrows - 1] = xnmalloc (ncolumns, sizeof (char *));
}

/* Output each cell in the table, accounting for the
   alignment and max width of each column.  */

static void
print_table (void)
{
  size_t row;

  for (row = 0; row < nrows; row++)
    {
      size_t col;
      for (col = 0; col < ncolumns; col++)
        {
          char *cell = table[row][col];

          /* Note the SOURCE_FIELD used to be displayed on it's own line
             if (!posix_format && mbswidth (cell) > 20), but that
             functionality was probably more problematic than helpful,
             hence changed in commit v8.10-40-g99679ff.  */
          if (col != 0)
            putchar (' ');

          int flags = 0;
          if (col == ncolumns - 1) /* The last one.  */
            flags = MBA_NO_RIGHT_PAD;

          size_t width = columns[col]->width;
          cell = ambsalign (cell, &width, columns[col]->align, flags);
          /* When ambsalign fails, output unaligned data.  */
          fputs (cell ? cell : table[row][col], stdout);
          free (cell);

          IF_LINT (free (table[row][col]));
        }
      putchar ('\n');
      putchar ('\r');
      IF_LINT (free (table[row]));
    }

  IF_LINT (free (table));
}

/* Dynamically allocate a struct field_t in COLUMNS, which
   can then be accessed with standard array notation.  */

static void
alloc_field (int f, const char *c)
{
  ncolumns++;
  columns = xnrealloc (columns, ncolumns, sizeof (struct field_data_t *));
  columns[ncolumns - 1] = &field_data[f];
  if (c != NULL)
    columns[ncolumns - 1]->caption = c;

  if (field_data[f].used)
    assert (!"field used");

  /* Mark field as used.  */
  field_data[f].used = true;
}


/* Given a string, ARG, containing a comma-separated list of arguments
   to the --output option, add the appropriate fields to columns.  */
static void
decode_output_arg (char const *arg)
{
  char *arg_writable = xstrdup (arg);
  char *s = arg_writable;
  do
    {
      /* find next comma */
      char *comma = strchr (s, ',');

      /* If we found a comma, put a NUL in its place and advance.  */
      if (comma)
        *comma++ = 0;

      /* process S.  */
      display_field_t field = INVALID_FIELD;
      for (unsigned int i = 0; i < ARRAY_CARDINALITY (field_data); i++)
        {
          if (STREQ (field_data[i].arg, s))
            {
              field = i;
              break;
            }
        }
      if (field == INVALID_FIELD)
        {
          error (0, 0, _("option --output: field %s unknown"), quote (s));
          usage (EXIT_FAILURE);
        }

      if (field_data[field].used)
        {
          /* Prevent the fields from being used more than once.  */
          error (0, 0, _("option --output: field %s used more than once"),
                 quote (field_data[field].arg));
          usage (EXIT_FAILURE);
        }

      switch (field)
        {
        case SOURCE_FIELD:
        case FSTYPE_FIELD:
        case USED_FIELD:
        case PCENT_FIELD:
        case ITOTAL_FIELD:
        case IUSED_FIELD:
        case IAVAIL_FIELD:
        case IPCENT_FIELD:
        case TARGET_FIELD:
        case FILE_FIELD:
          alloc_field (field, NULL);
          break;

        case SIZE_FIELD:
          alloc_field (field, N_("Size"));
          break;

        case AVAIL_FIELD:
          alloc_field (field, N_("Avail"));
          break;

        default:
          assert (!"invalid field");
        }
      s = comma;
    }
  while (s);

  free (arg_writable);
}

/* Get the appropriate columns for the mode.  */
static void
get_field_list (void)
{
  switch (header_mode)
    {
    case DEFAULT_MODE:
      alloc_field (SOURCE_FIELD, NULL);
      if (print_type)
        alloc_field (FSTYPE_FIELD, NULL);
      alloc_field (SIZE_FIELD,   NULL);
      alloc_field (USED_FIELD,   NULL);
      alloc_field (AVAIL_FIELD,  NULL);
      alloc_field (PCENT_FIELD,  NULL);
      alloc_field (TARGET_FIELD, NULL);
      break;

    case HUMAN_MODE:
      alloc_field (SOURCE_FIELD, NULL);
      if (print_type)
        alloc_field (FSTYPE_FIELD, NULL);

      alloc_field (SIZE_FIELD,   N_("Size"));
      alloc_field (USED_FIELD,   NULL);
      alloc_field (AVAIL_FIELD,  N_("Avail"));
      alloc_field (PCENT_FIELD,  NULL);
      alloc_field (TARGET_FIELD, NULL);
      break;

    case INODES_MODE:
      alloc_field (SOURCE_FIELD, NULL);
      if (print_type)
        alloc_field (FSTYPE_FIELD, NULL);
      alloc_field (ITOTAL_FIELD,  NULL);
      alloc_field (IUSED_FIELD,   NULL);
      alloc_field (IAVAIL_FIELD,  NULL);
      alloc_field (IPCENT_FIELD,  NULL);
      alloc_field (TARGET_FIELD,  NULL);
      break;

    case POSIX_MODE:
      alloc_field (SOURCE_FIELD, NULL);
      if (print_type)
        alloc_field (FSTYPE_FIELD, NULL);
      alloc_field (SIZE_FIELD,   NULL);
      alloc_field (USED_FIELD,   NULL);
      alloc_field (AVAIL_FIELD,  NULL);
      alloc_field (PCENT_FIELD,  N_("Capacity"));
      alloc_field (TARGET_FIELD, NULL);
      break;

    case OUTPUT_MODE:
      if (!ncolumns)
        {
          /* Add all fields if --output was given without a field list.  */
          decode_output_arg (all_args_string);
        }
      break;

    default:
      assert (!"invalid header_mode");
    }
}

/* Obtain the appropriate header entries.  */

static void
get_header (void)
{
  size_t col;

  alloc_table_row ();

  for (col = 0; col < ncolumns; col++)
    {
      char *cell = NULL;
      char const *header = _(columns[col]->caption);

      if (columns[col]->field == SIZE_FIELD
          && (header_mode == DEFAULT_MODE
              || (header_mode == OUTPUT_MODE
                  && !(human_output_opts & human_autoscale))))
        {
          char buf[LONGEST_HUMAN_READABLE + 1];

          int opts = (human_suppress_point_zero
                      | human_autoscale | human_SI
                      | (human_output_opts
                         & (human_group_digits | human_base_1024 | human_B)));

          /* Prefer the base that makes the human-readable value more exact,
             if there is a difference.  */

          uintmax_t q1000 = output_block_size;
          uintmax_t q1024 = output_block_size;
          bool divisible_by_1000;
          bool divisible_by_1024;

          do
            {
              divisible_by_1000 = q1000 % 1000 == 0;  q1000 /= 1000;
              divisible_by_1024 = q1024 % 1024 == 0;  q1024 /= 1024;
            }
          while (divisible_by_1000 & divisible_by_1024);

          if (divisible_by_1000 < divisible_by_1024)
            opts |= human_base_1024;
          if (divisible_by_1024 < divisible_by_1000)
            opts &= ~human_base_1024;
          if (! (opts & human_base_1024))
            opts |= human_B;

          char *num = human_readable (output_block_size, buf, opts, 1, 1);

          /* Reset the header back to the default in OUTPUT_MODE.  */
          header = _("blocks");

          /* TRANSLATORS: this is the "1K-blocks" header in "df" output.  */
          if (asprintf (&cell, _("%s-%s"), num, header) == -1)
            cell = NULL;
        }
      else if (header_mode == POSIX_MODE && columns[col]->field == SIZE_FIELD)
        {
          char buf[INT_BUFSIZE_BOUND (uintmax_t)];
          char *num = umaxtostr (output_block_size, buf);

          /* TRANSLATORS: this is the "1024-blocks" header in "df -P".  */
          if (asprintf (&cell, _("%s-%s"), num, header) == -1)
            cell = NULL;
        }
      else
        cell = strdup (header);

      if (!cell)
        xalloc_die ();

      hide_problematic_chars (cell);

      table[nrows - 1][col] = cell;

      columns[col]->width = MAX (columns[col]->width, mbswidth (cell, 0));
    }
}

/* Is FSTYPE a type of file system that should be listed?  */

static bool _GL_ATTRIBUTE_PURE
selected_fstype (const char *fstype)
{
  const struct fs_type_list *fsp;

  if (fs_select_list == NULL || fstype == NULL)
    return true;
  for (fsp = fs_select_list; fsp; fsp = fsp->fs_next)
    if (STREQ (fstype, fsp->fs_name))
      return true;
  return false;
}

/* Is FSTYPE a type of file system that should be omitted?  */

static bool _GL_ATTRIBUTE_PURE
excluded_fstype (const char *fstype)
{
  const struct fs_type_list *fsp;

  if (fs_exclude_list == NULL || fstype == NULL)
    return false;
  for (fsp = fs_exclude_list; fsp; fsp = fsp->fs_next)
    if (STREQ (fstype, fsp->fs_name))
      return true;
  return false;
}

static size_t
devlist_hash (void const *x, size_t table_size)
{
  struct devlist const *p = x;
  return (uintmax_t) p->dev_num % table_size;
}

static bool
devlist_compare (void const *x, void const *y)
{
  struct devlist const *a = x;
  struct devlist const *b = y;
  return a->dev_num == b->dev_num;
}

static struct devlist *
devlist_for_dev (dev_t dev)
{
  if (devlist_table == NULL)
    return NULL;
  struct devlist dev_entry;
  dev_entry.dev_num = dev;
  return hash_lookup (devlist_table, &dev_entry);
}

static void
devlist_free (void *p)
{
  free (p);
}

/* Filter mount list by skipping duplicate entries.
   In the case of duplicates - based on the device number - the mount entry
   with a '/' in its me_devname (i.e., not pseudo name like tmpfs) wins.
   If both have a real devname (e.g. bind mounts), then that with the shorter
   me_mountdir wins.  With DEVICES_ONLY == true (set with df -a), only update
   the global devlist_table, rather than filtering the global mount_list.  */

static void
filter_mount_list (bool devices_only)
{
  struct mount_entry *me;

  /* Temporary list to keep entries ordered.  */
  struct devlist *device_list = NULL;
  int mount_list_size = 0;

  for (me = mount_list; me; me = me->me_next)
    mount_list_size++;

  devlist_table = hash_initialize (mount_list_size, NULL,
                                 devlist_hash,
                                 devlist_compare,
                                 devlist_free);
  if (devlist_table == NULL)
    xalloc_die ();

  /* Sort all 'wanted' entries into the list device_list.  */
  for (me = mount_list; me;)
    {
      struct stat buf;
      struct mount_entry *discard_me = NULL;

      /* Avoid stating remote file systems as that may hang.
         On Linux we probably have me_dev populated from /proc/self/mountinfo,
         however we still stat() in case another device was mounted later.  */
      if ((me->me_remote && show_local_fs)
          || -1 == stat (me->me_mountdir, &buf))
        {
          /* If remote, and showing just local, add ME for filtering later.
             If stat failed; add ME to be able to complain about it later.  */
          buf.st_dev = me->me_dev;
        }
      else
        {
          /* If we've already seen this device...  */
          struct devlist *seen_dev = devlist_for_dev (buf.st_dev);

          if (seen_dev)
            {
              bool target_nearer_root = strlen (seen_dev->me->me_mountdir)
                                        > strlen (me->me_mountdir);
              /* With bind mounts, prefer items nearer the root of the source */
              bool source_below_root = seen_dev->me->me_mntroot != NULL
                                       && me->me_mntroot != NULL
                                       && (strlen (seen_dev->me->me_mntroot)
                                           < strlen (me->me_mntroot));
              if (! print_grand_total
                  && me->me_remote && seen_dev->me->me_remote
                  && ! STREQ (seen_dev->me->me_devname, me->me_devname))
                {
                  /* Don't discard remote entries with different locations,
                     as these are more likely to be explicitly mounted.
                     However avoid this when producing a total to give
                     a more accurate value in that case.  */
                }
              else if ((strchr (me->me_devname, '/')
                       /* let "real" devices with '/' in the name win.  */
                        && ! strchr (seen_dev->me->me_devname, '/'))
                       /* let points towards the root of the device win.  */
                       || (target_nearer_root && ! source_below_root)
                       /* let an entry overmounted on a new device win...  */
                       || (! STREQ (seen_dev->me->me_devname, me->me_devname)
                           /* ... but only when matching an existing mnt point,
                              to avoid problematic replacement when given
                              inaccurate mount lists, seen with some chroot
                              environments for example.  */
                           && STREQ (me->me_mountdir,
                                     seen_dev->me->me_mountdir)))
                {
                  /* Discard mount entry for existing device.  */
                  discard_me = seen_dev->me;
                  seen_dev->me = me;
                }
              else
                {
                  /* Discard mount entry currently being processed.  */
                  discard_me = me;
                }

            }
        }

      if (discard_me)
        {
          me = me->me_next;
          if (! devices_only)
            free_mount_entry (discard_me);
        }
      else
        {
          /* Add the device number to the device_table.  */
          struct devlist *devlist = xmalloc (sizeof *devlist);
          devlist->me = me;
          devlist->dev_num = buf.st_dev;
          devlist->next = device_list;
          device_list = devlist;
          if (hash_insert (devlist_table, devlist) == NULL)
            xalloc_die ();

          me = me->me_next;
        }
    }

  /* Finally rebuild the mount_list from the devlist.  */
  if (! devices_only) {
    mount_list = NULL;
    while (device_list)
      {
        /* Add the mount entry.  */
        me = device_list->me;
        me->me_next = mount_list;
        mount_list = me;
        device_list = device_list->next;
      }

      hash_free (devlist_table);
      devlist_table = NULL;
  }
}


/* Search a mount entry list for device id DEV.
   Return the corresponding mount entry if found or NULL if not.  */

static struct mount_entry const * _GL_ATTRIBUTE_PURE
me_for_dev (dev_t dev)
{
  struct devlist *dl = devlist_for_dev (dev);
  if (dl)
        return dl->me;

  return NULL;
}

/* Return true if N is a known integer value.  On many file systems,
   UINTMAX_MAX represents an unknown value; on AIX, UINTMAX_MAX - 1
   represents unknown.  Use a rule that works on AIX file systems, and
   that almost-always works on other types.  */
static bool
known_value (uintmax_t n)
{
  return n < UINTMAX_MAX - 1;
}

/* Like human_readable (N, BUF, human_output_opts, INPUT_UNITS, OUTPUT_UNITS),
   except:

    - If NEGATIVE, then N represents a negative number,
      expressed in two's complement.
    - Otherwise, return "-" if N is unknown.  */

static char const *
df_readable (bool negative, uintmax_t n, char *buf,
             uintmax_t input_units, uintmax_t output_units)
{
  if (! known_value (n) && !negative)
    return "-";
  else
    {
      char *p = human_readable (negative ? -n : n, buf + negative,
                                human_output_opts, input_units, output_units);
      if (negative)
        *--p = '-';
      return p;
    }
}

/* Logical equivalence */
#define LOG_EQ(a, b) (!(a) == !(b))

/* Add integral value while using uintmax_t for value part and separate
   negation flag.  It adds value of SRC and SRC_NEG to DEST and DEST_NEG.
   The result will be in DEST and DEST_NEG.  See df_readable to understand
   how the negation flag is used.  */
static void
add_uint_with_neg_flag (uintmax_t *dest, bool *dest_neg,
                        uintmax_t src, bool src_neg)
{
  if (LOG_EQ (*dest_neg, src_neg))
    {
      *dest += src;
      return;
    }

  if (*dest_neg)
    *dest = -*dest;

  if (src_neg)
    src = -src;

  if (src < *dest)
    *dest -= src;
  else
    {
      *dest = src - *dest;
      *dest_neg = src_neg;
    }

  if (*dest_neg)
    *dest = -*dest;
}

/* Return true if S ends in a string that may be a 36-byte UUID,
   i.e., of the form HHHHHHHH-HHHH-HHHH-HHHH-HHHHHHHHHHHH, where
   each H is an upper or lower case hexadecimal digit.  */
static bool _GL_ATTRIBUTE_PURE
has_uuid_suffix (char const *s)
{
  size_t len = strlen (s);
  return (36 < len
          && strspn (s + len - 36, "-0123456789abcdefABCDEF") == 36);
}

/* Obtain the block values BV and inode values IV
   from the file system usage FSU.  */
static void
get_field_values (struct field_values_t *bv,
                  struct field_values_t *iv,
                  const struct fs_usage *fsu)
{
  /* Inode values.  */
  iv->input_units = iv->output_units = 1;
  iv->total = fsu->fsu_files;
  iv->available = iv->available_to_root = fsu->fsu_ffree;
  iv->negate_available = false;

  iv->used = UINTMAX_MAX;
  iv->negate_used = false;
  if (known_value (iv->total) && known_value (iv->available_to_root))
    {
      iv->used = iv->total - iv->available_to_root;
      iv->negate_used = (iv->total < iv->available_to_root);
    }

  /* Block values.  */
  bv->input_units = fsu->fsu_blocksize;
  bv->output_units = output_block_size;
  bv->total = fsu->fsu_blocks;
  bv->available = fsu->fsu_bavail;
  bv->available_to_root = fsu->fsu_bfree;
  bv->negate_available = (fsu->fsu_bavail_top_bit_set
                         && known_value (fsu->fsu_bavail));

  bv->used = UINTMAX_MAX;
  bv->negate_used = false;
  if (known_value (bv->total) && known_value (bv->available_to_root))
    {
      bv->used = bv->total - bv->available_to_root;
      bv->negate_used = (bv->total < bv->available_to_root);
    }
}

/* Add block and inode values to grand total.  */
static void
add_to_grand_total (struct field_values_t *bv, struct field_values_t *iv)
{
  if (known_value (iv->total))
    grand_fsu.fsu_files += iv->total;
  if (known_value (iv->available))
    grand_fsu.fsu_ffree += iv->available;

  if (known_value (bv->total))
    grand_fsu.fsu_blocks += bv->input_units * bv->total;
  if (known_value (bv->available_to_root))
    grand_fsu.fsu_bfree += bv->input_units * bv->available_to_root;
  if (known_value (bv->available))
    add_uint_with_neg_flag (&grand_fsu.fsu_bavail,
                            &grand_fsu.fsu_bavail_top_bit_set,
                            bv->input_units * bv->available,
                            bv->negate_available);
}

/* Obtain a space listing for the disk device with absolute file name DISK.
   If MOUNT_POINT is non-NULL, it is the name of the root of the
   file system on DISK.
   If STAT_FILE is non-null, it is the name of a file within the file
   system that the user originally asked for; this provides better
   diagnostics, and sometimes it provides better results on networked
   file systems that give different free-space results depending on
   where in the file system you probe.
   If FSTYPE is non-NULL, it is the type of the file system on DISK.
   If MOUNT_POINT is non-NULL, then DISK may be NULL -- certain systems may
   not be able to produce statistics in this case.
   ME_DUMMY and ME_REMOTE are the mount entry flags.
   Caller must set PROCESS_ALL to true when iterating over all entries, as
   when df is invoked with no non-option argument.  See below for details.  */

static void
get_dev (char const *disk, char const *mount_point, char const* file,
         char const *stat_file, char const *fstype,
         bool me_dummy, bool me_remote,
         const struct fs_usage *force_fsu,
         bool process_all)
{
  if (me_remote && show_local_fs)
    return;

  if (me_dummy && !show_all_fs && !show_listed_fs)
    return;

  if (!selected_fstype (fstype) || excluded_fstype (fstype))
    return;

  /* Ignore relative MOUNT_POINTs, which are present for example
     in /proc/mounts on Linux with network namespaces.  */
  if (!force_fsu && mount_point && ! IS_ABSOLUTE_FILE_NAME (mount_point))
    return;

  /* If MOUNT_POINT is NULL, then the file system is not mounted, and this
     program reports on the file system that the special file is on.
     It would be better to report on the unmounted file system,
     but statfs doesn't do that on most systems.  */
  if (!stat_file)
    stat_file = mount_point ? mount_point : disk;

  struct fs_usage fsu;
  if (force_fsu)
    fsu = *force_fsu;
  else if (get_fs_usage (stat_file, disk, &fsu))
    {
      /* If we can't access a system provided entry due
         to it not being present (now), or due to permissions,
         just output placeholder values rather than failing.  */
      if (process_all && (errno == EACCES || errno == ENOENT))
        {
          if (! show_all_fs)
            return;

          fstype = "-";
          fsu.fsu_bavail_top_bit_set = false;
          fsu.fsu_blocksize = fsu.fsu_blocks = fsu.fsu_bfree =
          fsu.fsu_bavail = fsu.fsu_files = fsu.fsu_ffree = UINTMAX_MAX;
        }
      else
        {
          error (0, errno, "%s", quotef (stat_file));
          exit_status = EXIT_FAILURE;
          return;
        }
    }
  else if (process_all && show_all_fs)
    {
      /* Ensure we don't output incorrect stats for over-mounted directories.
         Discard stats when the device name doesn't match.  Though don't
         discard when used and current mount entries are both remote due
         to the possibility of aliased host names or exports.  */
      struct stat sb;
      if (stat (stat_file, &sb) == 0)
        {
          struct mount_entry const * dev_me = me_for_dev (sb.st_dev);
          if (dev_me && ! STREQ (dev_me->me_devname, disk)
              && (! dev_me->me_remote || ! me_remote))
            {
              fstype = "-";
              fsu.fsu_bavail_top_bit_set = false;
              fsu.fsu_blocksize = fsu.fsu_blocks = fsu.fsu_bfree =
              fsu.fsu_bavail = fsu.fsu_files = fsu.fsu_ffree = UINTMAX_MAX;
            }
        }
    }

  if (fsu.fsu_blocks == 0 && !show_all_fs && !show_listed_fs)
    return;

  if (! force_fsu)
    file_systems_processed = true;

  alloc_table_row ();

  if (! disk)
    disk = "-";			/* unknown */

  if (! file)
    file = "-";			/* unspecified */

  char *dev_name = xstrdup (disk);
  char *resolved_dev;

  /* On some systems, dev_name is a long-named symlink like
     /dev/disk/by-uuid/828fc648-9f30-43d8-a0b1-f7196a2edb66 pointing to a
     much shorter and more useful name like /dev/sda1.  It may also look
     like /dev/mapper/luks-828fc648-9f30-43d8-a0b1-f7196a2edb66 and point to
     /dev/dm-0.  When process_all is true and dev_name is a symlink whose
     name ends with a UUID use the resolved name instead.  */
  if (process_all
      && has_uuid_suffix (dev_name)
      && (resolved_dev = canonicalize_filename_mode (dev_name, CAN_EXISTING)))
    {
      free (dev_name);
      dev_name = resolved_dev;
    }

  if (! fstype)
    fstype = "-";		/* unknown */

  struct field_values_t block_values;
  struct field_values_t inode_values;
  get_field_values (&block_values, &inode_values, &fsu);

  /* Add to grand total unless processing grand total line.  */
  if (print_grand_total && ! force_fsu)
    add_to_grand_total (&block_values, &inode_values);

  size_t col;
  for (col = 0; col < ncolumns; col++)
    {
      char buf[LONGEST_HUMAN_READABLE + 2];
      char *cell;

      struct field_values_t *v;
      switch (columns[col]->field_type)
        {
        case BLOCK_FLD:
          v = &block_values;
          break;
        case INODE_FLD:
          v = &inode_values;
          break;
        case OTHER_FLD:
          v = NULL;
          break;
        default:
          v = NULL; /* Avoid warnings where assert() is not __noreturn__.  */
          assert (!"bad field_type");
        }

      switch (columns[col]->field)
        {
        case SOURCE_FIELD:
          cell = xstrdup (dev_name);
          break;

        case FSTYPE_FIELD:
          cell = xstrdup (fstype);
          break;

        case SIZE_FIELD:
        case ITOTAL_FIELD:
          cell = xstrdup (df_readable (false, v->total, buf,
                                       v->input_units, v->output_units));
          break;

        case USED_FIELD:
        case IUSED_FIELD:
          cell = xstrdup (df_readable (v->negate_used, v->used, buf,
                                       v->input_units, v->output_units));
          break;

        case AVAIL_FIELD:
        case IAVAIL_FIELD:
          cell = xstrdup (df_readable (v->negate_available, v->available, buf,
                                       v->input_units, v->output_units));
          break;

        case PCENT_FIELD:
        case IPCENT_FIELD:
          {
            double pct = -1;
            if (! known_value (v->used) || ! known_value (v->available))
              ;
            else if (!v->negate_used
                     && v->used <= TYPE_MAXIMUM (uintmax_t) / 100
                     && v->used + v->available != 0
                     && (v->used + v->available < v->used)
                     == v->negate_available)
              {
                uintmax_t u100 = v->used * 100;
                uintmax_t nonroot_total = v->used + v->available;
                pct = u100 / nonroot_total + (u100 % nonroot_total != 0);
              }
            else
              {
                /* The calculation cannot be done easily with integer
                   arithmetic.  Fall back on floating point.  This can suffer
                   from minor rounding errors, but doing it exactly requires
                   multiple precision arithmetic, and it's not worth the
                   aggravation.  */
                double u = v->negate_used ? - (double) - v->used : v->used;
                double a = v->negate_available
                           ? - (double) - v->available : v->available;
                double nonroot_total = u + a;
                if (nonroot_total)
                  {
                    long int lipct = pct = u * 100 / nonroot_total;
                    double ipct = lipct;

                    /* Like 'pct = ceil (dpct);', but avoid ceil so that
                       the math library needn't be linked.  */
                    if (ipct - 1 < pct && pct <= ipct + 1)
                      pct = ipct + (ipct < pct);
                  }
              }

            if (0 <= pct)
              {
                if (asprintf (&cell, "%.0f%%", pct) == -1)
                  cell = NULL;
              }
            else
              cell = strdup ("-");

            if (!cell)
              xalloc_die ();

            break;
          }

        case FILE_FIELD:
          cell = xstrdup (file);
          break;

        case TARGET_FIELD:
#ifdef HIDE_AUTOMOUNT_PREFIX
          /* Don't print the first directory name in MOUNT_POINT if it's an
             artifact of an automounter.  This is a bit too aggressive to be
             the default.  */
          if (STRNCMP_LIT (mount_point, "/auto/") == 0)
            mount_point += 5;
          else if (STRNCMP_LIT (mount_point, "/tmp_mnt/") == 0)
            mount_point += 8;
#endif
          cell = xstrdup (mount_point);
          break;

        default:
          assert (!"unhandled field");
        }

      if (!cell)
        assert (!"empty cell");

      hide_problematic_chars (cell);
      columns[col]->width = MAX (columns[col]->width, mbswidth (cell, 0));
      table[nrows - 1][col] = cell;
    }
  free (dev_name);
}

/* Scan the mount list returning the _last_ device found for MOUNT.
   NULL is returned if MOUNT not found.  The result is malloced.  */
static char *
last_device_for_mount (char const* mount)
{
  struct mount_entry const *me;
  struct mount_entry const *le = NULL;

  for (me = mount_list; me; me = me->me_next)
    {
      if (STREQ (me->me_mountdir, mount))
        le = me;
    }

  if (le)
    {
      char *devname = le->me_devname;
      char *canon_dev = canonicalize_file_name (devname);
      if (canon_dev && IS_ABSOLUTE_FILE_NAME (canon_dev))
        return canon_dev;
      free (canon_dev);
      return xstrdup (le->me_devname);
    }
  else
    return NULL;
}

/* If DISK corresponds to a mount point, show its usage
   and return true.  Otherwise, return false.  */
static bool
get_disk (char const *disk)
{
  struct mount_entry const *me;
  struct mount_entry const *best_match = NULL;
  bool best_match_accessible = false;
  bool eclipsed_device = false;
  char const *file = disk;

  char *resolved = canonicalize_file_name (disk);
  if (resolved && IS_ABSOLUTE_FILE_NAME (resolved))
    disk = resolved;

  size_t best_match_len = SIZE_MAX;
  for (me = mount_list; me; me = me->me_next)
    {
      /* TODO: Should cache canon_dev in the mount_entry struct.  */
      char *devname = me->me_devname;
      char *canon_dev = canonicalize_file_name (me->me_devname);
      if (canon_dev && IS_ABSOLUTE_FILE_NAME (canon_dev))
        devname = canon_dev;

      if (STREQ (disk, devname))
        {
          char *last_device = last_device_for_mount (me->me_mountdir);
          eclipsed_device = last_device && ! STREQ (last_device, devname);
          size_t len = strlen (me->me_mountdir);

          if (! eclipsed_device
              && (! best_match_accessible || len < best_match_len))
            {
              struct stat disk_stats;
              bool this_match_accessible = false;

              if (stat (me->me_mountdir, &disk_stats) == 0)
                best_match_accessible = this_match_accessible = true;

              if (this_match_accessible
                  || (! best_match_accessible && len < best_match_len))
                {
                  best_match = me;
                  if (len == 1) /* Traditional root.  */
                    {
                      free (last_device);
                      free (canon_dev);
                      break;
                    }
                  else
                    best_match_len = len;
                }
            }

          free (last_device);
        }

      free (canon_dev);
    }

  free (resolved);

  if (best_match)
    {
      get_dev (best_match->me_devname, best_match->me_mountdir, file, NULL,
               best_match->me_type, best_match->me_dummy,
               best_match->me_remote, NULL, false);
      return true;
    }
  else if (eclipsed_device)
    {
      error (0, 0, _("cannot access %s: over-mounted by another device"),
             quoteaf (file));
      exit_status = EXIT_FAILURE;
      return true;
    }

  return false;
}

/* Figure out which device file or directory POINT is mounted on
   and show its disk usage.
   STATP must be the result of 'stat (POINT, STATP)'.  */
static void
get_point (const char *point, const struct stat *statp)
{
  struct stat disk_stats;
  struct mount_entry *me;
  struct mount_entry const *best_match = NULL;

  /* Calculate the real absolute file name for POINT, and use that to find
     the mount point.  This avoids statting unavailable mount points,
     which can hang df.  */
  char *resolved = canonicalize_file_name (point);
  if (resolved && resolved[0] == '/')
    {
      size_t resolved_len = strlen (resolved);
      size_t best_match_len = 0;

      for (me = mount_list; me; me = me->me_next)
        {
          if (!STREQ (me->me_type, "lofs")
              && (!best_match || best_match->me_dummy || !me->me_dummy))
            {
              size_t len = strlen (me->me_mountdir);
              if (best_match_len <= len && len <= resolved_len
                  && (len == 1 /* root file system */
                      || ((len == resolved_len || resolved[len] == '/')
                          && STREQ_LEN (me->me_mountdir, resolved, len))))
                {
                  best_match = me;
                  best_match_len = len;
                }
            }
        }
    }
  free (resolved);
  if (best_match
      && (stat (best_match->me_mountdir, &disk_stats) != 0
          || disk_stats.st_dev != statp->st_dev))
    best_match = NULL;

  if (! best_match)
    for (me = mount_list; me; me = me->me_next)
      {
        if (me->me_dev == (dev_t) -1)
          {
            if (stat (me->me_mountdir, &disk_stats) == 0)
              me->me_dev = disk_stats.st_dev;
            else
              {
                /* Report only I/O errors.  Other errors might be
                   caused by shadowed mount points, which means POINT
                   can't possibly be on this file system.  */
                if (errno == EIO)
                  {
                    error (0, errno, "%s", quotef (me->me_mountdir));
                    exit_status = EXIT_FAILURE;
                  }

                /* So we won't try and fail repeatedly.  */
                me->me_dev = (dev_t) -2;
              }
          }

        if (statp->st_dev == me->me_dev
            && !STREQ (me->me_type, "lofs")
            && (!best_match || best_match->me_dummy || !me->me_dummy))
          {
            /* Skip bogus mtab entries.  */
            if (stat (me->me_mountdir, &disk_stats) != 0
                || disk_stats.st_dev != me->me_dev)
              me->me_dev = (dev_t) -2;
            else
              best_match = me;
          }
      }

  if (best_match)
    get_dev (best_match->me_devname, best_match->me_mountdir, point, point,
             best_match->me_type, best_match->me_dummy, best_match->me_remote,
             NULL, false);
  else
    {
      /* We couldn't find the mount entry corresponding to POINT.  Go ahead and
         print as much info as we can; methods that require the device to be
         present will fail at a later point.  */

      /* Find the actual mount point.  */
      char *mp = find_mount_point (point, statp);
      if (mp)
        {
          get_dev (NULL, mp, point, NULL, NULL, false, false, NULL, false);
          free (mp);
        }
    }
}

/* Determine what kind of node NAME is and show the disk usage
   for it.  STATP is the results of 'stat' on NAME.  */

static void
get_entry (char const *name, struct stat const *statp)
{
  if ((S_ISBLK (statp->st_mode) || S_ISCHR (statp->st_mode))
      && get_disk (name))
    return;

  get_point (name, statp);
}

/* Show all mounted file systems, except perhaps those that are of
   an unselected type or are empty.  */

static void
get_all_entries (void)
{
  struct mount_entry *me;

  filter_mount_list (show_all_fs);

  for (me = mount_list; me; me = me->me_next)
    get_dev (me->me_devname, me->me_mountdir, NULL, NULL, me->me_type,
             me->me_dummy, me->me_remote, NULL, true);
}

/* Add FSTYPE to the list of file system types to display.  */

static void
add_fs_type (const char *fstype)
{
  struct fs_type_list *fsp;

  fsp = xmalloc (sizeof *fsp);
  fsp->fs_name = (char *) fstype;
  fsp->fs_next = fs_select_list;
  fs_select_list = fsp;
}

/* Add FSTYPE to the list of file system types to be omitted.  */

static void
add_excluded_fs_type (const char *fstype)
{
  struct fs_type_list *fsp;

  fsp = xmalloc (sizeof *fsp);
  fsp->fs_name = (char *) fstype;
  fsp->fs_next = fs_exclude_list;
  fs_exclude_list = fsp;
}

void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("Usage: %s [OPTION]... [FILE]...\n\r"), program_name);
      fputs (_("\
Show information about the file system on which each FILE resides,\n\r\
or all file systems by default.\n\r\
"), stdout);

      emit_mandatory_arg_note ();

      /* TRANSLATORS: The thousands and decimal separators are best
         adjusted to an appropriate default for your locale.  */
      fputs (_("\
  -a, --all             include pseudo, duplicate, inaccessible file systems\n\r\
  -B, --block-size=SIZE  scale sizes by SIZE before printing them; e.g.,\n\r\
                           '-BM' prints sizes in units of 1,048,576 bytes;\n\r\
                           see SIZE format below\n\r\
  -h, --human-readable  print sizes in powers of 1024 (e.g., 1023M)\n\r\
  -H, --si              print sizes in powers of 1000 (e.g., 1.1G)\n\r\
"), stdout);
      fputs (_("\
  -i, --inodes          list inode information instead of block usage\n\r\
  -k                    like --block-size=1K\n\r\
  -l, --local           limit listing to local file systems\n\r\
      --no-sync         do not invoke sync before getting usage info (default)\
\n\r\
"), stdout);
      fputs (_("\
      --output[=FIELD_LIST]  use the output format defined by FIELD_LIST,\n\r\
                               or print all fields if FIELD_LIST is omitted.\n\r\
  -P, --portability     use the POSIX output format\n\r\
      --sync            invoke sync before getting usage info\n\r\
"), stdout);
      fputs (_("\
      --total           elide all entries insignificant to available space,\n\r\
                          and produce a grand total\n\r\
"), stdout);
      fputs (_("\
  -t, --type=TYPE       limit listing to file systems of type TYPE\n\r\
  -T, --print-type      print file system type\n\r\
  -x, --exclude-type=TYPE   limit listing to file systems not of type TYPE\n\r\
  -v                    (ignored)\n\r\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      emit_blocksize_note ("DF");
      emit_size_note ();
      fputs (_("\n\r\
FIELD_LIST is a comma-separated list of columns to be included.  Valid\n\r\
field names are: 'source', 'fstype', 'itotal', 'iused', 'iavail', 'ipcent',\n\r\
'size', 'used', 'avail', 'pcent', 'file' and 'target' (see info page).\n\r\
"), stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  // exit (status);
}

int
df_main (int argc, char **argv)
{
  struct stat *stats IF_LINT ( = 0);

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  fs_select_list = NULL;
  fs_exclude_list = NULL;
  show_all_fs = false;
  show_listed_fs = false;
  human_output_opts = -1;
  print_type = false;
  file_systems_processed = false;
  exit_status = EXIT_SUCCESS;
  print_grand_total = false;
  grand_fsu.fsu_blocksize = 1;

  /* If true, use the POSIX output format.  */
  bool posix_format = false;

  const char *msg_mut_excl = _("options %s and %s are mutually exclusive");

  while (true)
    {
      int oi = -1;
      int c = getopt_long (argc, argv, "aB:iF:hHklmPTt:vx:", long_options,
                           &oi);
      if (c == -1)
        break;

      switch (c)
        {
        case 'a':
          show_all_fs = true;
          break;
        case 'B':
          {
            enum strtol_error e = human_options (optarg, &human_output_opts,
                                                 &output_block_size);
            if (e != LONGINT_OK)
              xstrtol_fatal (e, oi, c, long_options, optarg);
          }
          break;
        case 'i':
          if (header_mode == OUTPUT_MODE)
            {
              error (0, 0, msg_mut_excl, "-i", "--output");
              df_usage (EXIT_FAILURE);
                return EXIT_FAILURE;
            }
          header_mode = INODES_MODE;
          break;
        case 'h':
          human_output_opts = human_autoscale | human_SI | human_base_1024;
          output_block_size = 1;
          break;
        case 'H':
          human_output_opts = human_autoscale | human_SI;
          output_block_size = 1;
          break;
        case 'k':
          human_output_opts = 0;
          output_block_size = 1024;
          break;
        case 'l':
          show_local_fs = true;
          break;
        case 'm': /* obsolescent, exists for BSD compatibility */
          human_output_opts = 0;
          output_block_size = 1024 * 1024;
          break;
        case 'T':
          if (header_mode == OUTPUT_MODE)
            {
              error (0, 0, msg_mut_excl, "-T", "--output");
              df_usage (EXIT_FAILURE);
              return  EXIT_FAILURE;
            }
          print_type = true;
          break;
        case 'P':
          if (header_mode == OUTPUT_MODE)
            {
              error (0, 0, msg_mut_excl, "-P", "--output");
              df_usage (EXIT_FAILURE);
                return EXIT_FAILURE;
            }
          posix_format = true;
          break;
        case SYNC_OPTION:
          require_sync = true;
          break;
        case NO_SYNC_OPTION:
          require_sync = false;
          break;

        case 'F':
          /* Accept -F as a synonym for -t for compatibility with Solaris.  */
        case 't':
          add_fs_type (optarg);
          break;

        case 'v':		/* For SysV compatibility.  */
          /* ignore */
          break;
        case 'x':
          add_excluded_fs_type (optarg);
          break;

        case OUTPUT_OPTION:
          if (header_mode == INODES_MODE)
            {
              error (0, 0, msg_mut_excl, "-i", "--output");
              df_usage (EXIT_FAILURE);
                return EXIT_FAILURE;
            }
          if (posix_format && header_mode == DEFAULT_MODE)
            {
              error (0, 0, msg_mut_excl, "-P", "--output");
              df_usage (EXIT_FAILURE);
                return EXIT_FAILURE;
            }
          if (print_type)
            {
              error (0, 0, msg_mut_excl, "-T", "--output");
              df_usage (EXIT_FAILURE);
                return EXIT_FAILURE;
            }
          header_mode = OUTPUT_MODE;
          if (optarg)
            decode_output_arg (optarg);
          break;

        case TOTAL_OPTION:
          print_grand_total = true;
          break;

        case_GETOPT_HELP_CHAR;
        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);

        default:
          df_usage (EXIT_FAILURE);
          return EXIT_FAILURE;
        }
    }

  if (human_output_opts == -1)
    {
      if (posix_format)
        {
          human_output_opts = 0;
          output_block_size = (getenv ("POSIXLY_CORRECT") ? 512 : 1024);
        }
      else
        human_options (getenv ("DF_BLOCK_SIZE"),
                       &human_output_opts, &output_block_size);
    }

  if (header_mode == INODES_MODE || header_mode == OUTPUT_MODE)
    ;
  else if (human_output_opts & human_autoscale)
    header_mode = HUMAN_MODE;
  else if (posix_format)
    header_mode = POSIX_MODE;

  /* Fail if the same file system type was both selected and excluded.  */
  {
    bool match = false;
    struct fs_type_list *fs_incl;
    for (fs_incl = fs_select_list; fs_incl; fs_incl = fs_incl->fs_next)
      {
        struct fs_type_list *fs_excl;
        for (fs_excl = fs_exclude_list; fs_excl; fs_excl = fs_excl->fs_next)
          {
            if (STREQ (fs_incl->fs_name, fs_excl->fs_name))
              {
                error (0, 0,
                       _("file system type %s both selected and excluded"),
                       quote (fs_incl->fs_name));
                match = true;
                break;
              }
          }
      }
    if (match)
      return EXIT_FAILURE;
  }

  assume (0 < optind);

  if (optind < argc)
    {
      int i;

      /* Open each of the given entries to make sure any corresponding
         partition is automounted.  This must be done before reading the
         file system table.  */
      stats = xnmalloc (argc - optind, sizeof *stats);
      for (i = optind; i < argc; ++i)
        {
          /* Prefer to open with O_NOCTTY and use fstat, but fall back
             on using "stat", in case the file is unreadable.  */
          int fd = open (argv[i], O_RDONLY | O_NOCTTY);
          if ((fd < 0 || fstat (fd, &stats[i - optind]))
              && stat (argv[i], &stats[i - optind]))
            {
              error (0, errno, "%s", quotef (argv[i]));
              exit_status = EXIT_FAILURE;
              argv[i] = NULL;
            }
          if (0 <= fd)
            close (fd);
        }
    }

  mount_list =
    read_file_system_list ((fs_select_list != NULL
                            || fs_exclude_list != NULL
                            || print_type
                            || field_data[FSTYPE_FIELD].used
                            || show_local_fs));

  if (mount_list == NULL)
    {
      /* Couldn't read the table of mounted file systems.
         Fail if df was invoked with no file name arguments,
         or when either of -a, -l, -t or -x is used with file name
         arguments.  Otherwise, merely give a warning and proceed.  */
      int status = 0;
      if ( ! (optind < argc)
           || (show_all_fs
               || show_local_fs
               || fs_select_list != NULL
               || fs_exclude_list != NULL))
        {
          status = EXIT_FAILURE;
        }
      const char *warning = (status == 0 ? _("Warning: ") : "");
      error (status, errno, "%s%s", warning,
             _("cannot read table of mounted file systems"));
    }

  if (require_sync)
    sync ();

  get_field_list ();
  get_header ();

  if (optind < argc)
    {
      int i;

      /* Display explicitly requested empty file systems.  */
      show_listed_fs = true;

      for (i = optind; i < argc; ++i)
        if (argv[i])
          get_entry (argv[i], &stats[i - optind]);

      IF_LINT (free (stats));
    }
  else
    get_all_entries ();

  if (file_systems_processed)
    {
      if (print_grand_total)
        get_dev ("total",
                 (field_data[SOURCE_FIELD].used ? "-" : "total"),
                 NULL, NULL, NULL, false, false, &grand_fsu, false);

      print_table ();
    }
  else
    {
      /* Print the "no FS processed" diagnostic only if there was no preceding
         diagnostic, e.g., if all have been excluded.  */
      if (exit_status == EXIT_SUCCESS)
        die (EXIT_FAILURE, 0, _("no file systems processed"));
    }

  IF_LINT (free (columns));

  return exit_status;
}
