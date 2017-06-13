/* system-dependent definitions for coreutils
   Copyright (C) 1989-2017 Free Software Foundation, Inc.

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

/* Include this file _after_ system headers if possible.  */

#include <alloca.h>

#include <sys/stat.h>

/* Commonly used file permission combination.  */
#define MODE_RW_UGO (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH)

#if !defined HAVE_MKFIFO
# define mkfifo(name, mode) mknod (name, (mode) | S_IFIFO, 0)
#endif

#if HAVE_SYS_PARAM_H
# include <sys/param.h>
#endif

#include <unistd.h>

#include <limits.h>

#include "pathmax.h"
#ifndef PATH_MAX
# define PATH_MAX 8192
#endif

#include "configmake.h"

#include <sys/time.h>
#include <time.h>

/* Since major is a function on SVR4, we can't use 'ifndef major'.  */
#if MAJOR_IN_MKDEV
# include <sys/mkdev.h>
# define HAVE_MAJOR
#endif
#if MAJOR_IN_SYSMACROS
# include <sys/sysmacros.h>
# define HAVE_MAJOR
#endif
#ifdef major			/* Might be defined in sys/types.h.  */
# define HAVE_MAJOR
#endif

#ifndef HAVE_MAJOR
# define major(dev)  (((dev) >> 8) & 0xff)
# define minor(dev)  ((dev) & 0xff)
# define makedev(maj, min)  (((maj) << 8) | (min))
#endif
#undef HAVE_MAJOR

#if ! defined makedev && defined mkdev
# define makedev(maj, min)  mkdev (maj, min)
#endif

#include <string.h>
#include <errno.h>

/* Some systems don't define this; POSIX mentions it but says it is
   obsolete.  gnulib defines it, but only on native Windows systems,
   and there only because MSVC 10 does.  */
#ifndef ENODATA
# define ENODATA (-1)
#endif

#include <stdbool.h>
#include <stdlib.h>
#include "version.h"

/* Exit statuses for programs like 'env' that exec other programs.  */
enum
{
  EXIT_TIMEDOUT = 124, /* Time expired before child completed.  */
  EXIT_CANCELED = 125, /* Internal error prior to exec attempt.  */
  EXIT_CANNOT_INVOKE = 126, /* Program located, but not usable.  */
  EXIT_ENOENT = 127 /* Could not find program to exec.  */
};

#include "exitfail.h"

/* Set exit_failure to STATUS if that's not the default already.  */
static inline void
initialize_exit_failure (int status)
{
  if (status != EXIT_FAILURE)
    exit_failure = status;
}

#include <fcntl.h>

#include <dirent.h>
#ifndef _D_EXACT_NAMLEN
# define _D_EXACT_NAMLEN(dp) strlen ((dp)->d_name)
#endif

enum
{
  NOT_AN_INODE_NUMBER = 0
};

#ifdef D_INO_IN_DIRENT
# define D_INO(dp) (dp)->d_ino
#else
/* Some systems don't have inodes, so fake them to avoid lots of ifdefs.  */
# define D_INO(dp) NOT_AN_INODE_NUMBER
#endif

/* include here for SIZE_MAX.  */
#include <inttypes.h>

/* Redirection and wildcarding when done by the utility itself.
   Generally a noop, but used in particular for OS/2.  */
#ifndef initialize_main
# ifndef __OS2__
#  define initialize_main(ac, av)
# else
#  define initialize_main(ac, av) \
     do { _wildcard (ac, av); _response (ac, av); } while (0)
# endif
#endif

#include "stat-macros.h"

#include "timespec.h"

#include <ctype.h>

/* ISDIGIT differs from isdigit, as follows:
   - Its arg may be any int or unsigned int; it need not be an unsigned char
     or EOF.
   - It's typically faster.
   POSIX says that only '0' through '9' are digits.  Prefer ISDIGIT to
   isdigit unless it's important to use the locale's definition
   of 'digit' even when the host does not conform to POSIX.  */
#define ISDIGIT(c) ((unsigned int) (c) - '0' <= 9)

/* Convert a possibly-signed character to an unsigned character.  This is
   a bit safer than casting to unsigned char, since it catches some type
   errors that the cast doesn't.  */
static inline unsigned char to_uchar (char ch) { return ch; }

/* '\n' is considered a field separator with  --zero-terminated.  */
static inline bool
field_sep (unsigned char ch)
{
  return isblank (ch) || ch == '\n';
}

#include <locale.h>

/* Take care of NLS matters.  */

#include "gettext.h"
#if ! ENABLE_NLS
# undef textdomain
# define textdomain(Domainname) /* empty */
# undef bindtextdomain
# define bindtextdomain(Domainname, Dirname) /* empty */
#endif

#define _(msgid) gettext (msgid)
#define N_(msgid) msgid

/* Return a value that pluralizes the same way that N does, in all
   languages we know of.  */
static inline unsigned long int
select_plural (uintmax_t n)
{
  /* Reduce by a power of ten, but keep it away from zero.  The
     gettext manual says 1000000 should be safe.  */
  enum { PLURAL_REDUCER = 1000000 };
  return (n <= ULONG_MAX ? n : n % PLURAL_REDUCER + PLURAL_REDUCER);
}

#define STREQ(a, b) (strcmp (a, b) == 0)
#define STREQ_LEN(a, b, n) (strncmp (a, b, n) == 0)
#define STRPREFIX(a, b) (strncmp (a, b, strlen (b)) == 0)

/* Just like strncmp, but the second argument must be a literal string
   and you don't specify the length;  that comes from the literal.  */
#define STRNCMP_LIT(s, lit) strncmp (s, "" lit "", sizeof (lit) - 1)

#if !HAVE_DECL_GETLOGIN
char *getlogin (void);
#endif

#if !HAVE_DECL_TTYNAME
char *ttyname (int);
#endif

#if !HAVE_DECL_GETEUID
uid_t geteuid (void);
#endif

#if !HAVE_DECL_GETPWUID
struct passwd *getpwuid (uid_t);
#endif

#if !HAVE_DECL_GETGRGID
struct group *getgrgid (gid_t);
#endif

/* Interix has replacements for getgr{gid,nam,ent}, that don't
   query the domain controller for group members when not required.
   This speeds up the calls tremendously (<1 ms vs. >3 s). */
/* To protect any system that could provide _nomembers functions
   other than interix, check for HAVE_SETGROUPS, as interix is
   one of the very few (the only?) platform that lacks it */
#if ! HAVE_SETGROUPS
# if HAVE_GETGRGID_NOMEMBERS
#  define getgrgid(gid) getgrgid_nomembers(gid)
# endif
# if HAVE_GETGRNAM_NOMEMBERS
#  define getgrnam(nam) getgrnam_nomembers(nam)
# endif
# if HAVE_GETGRENT_NOMEMBERS
#  define getgrent() getgrent_nomembers()
# endif
#endif

#if !HAVE_DECL_GETUID
uid_t getuid (void);
#endif

#include "xalloc.h"
#include "verify.h"

/* This is simply a shorthand for the common case in which
   the third argument to x2nrealloc would be 'sizeof *(P)'.
   Ensure that sizeof *(P) is *not* 1.  In that case, it'd be
   better to use X2REALLOC, although not strictly necessary.  */
#define X2NREALLOC(P, PN) ((void) verify_true (sizeof *(P) != 1), \
                           x2nrealloc (P, PN, sizeof *(P)))

/* Using x2realloc (when appropriate) usually makes your code more
   readable than using x2nrealloc, but it also makes it so your
   code will malfunction if sizeof *(P) ever becomes 2 or greater.
   So use this macro instead of using x2realloc directly.  */
#define X2REALLOC(P, PN) ((void) verify_true (sizeof *(P) == 1), \
                          x2realloc (P, PN))

#include "unlocked-io.h"
#include "same-inode.h"

#include "dirname.h"
#include "openat.h"

static inline bool
dot_or_dotdot (char const *file_name)
{
  if (file_name[0] == '.')
    {
      char sep = file_name[(file_name[1] == '.') + 1];
      return (! sep || ISSLASH (sep));
    }
  else
    return false;
}

/* A wrapper for readdir so that callers don't see entries for '.' or '..'.  */
static inline struct dirent const *
readdir_ignoring_dot_and_dotdot (DIR *dirp)
{
  while (1)
    {
      struct dirent const *dp = readdir (dirp);
      if (dp == NULL || ! dot_or_dotdot (dp->d_name))
        return dp;
    }
}

/* Return true if DIR is determined to be an empty directory.  */
static inline bool
is_empty_dir (int fd_cwd, char const *dir)
{
  DIR *dirp;
  struct dirent const *dp;
  int saved_errno;
  int fd = openat (fd_cwd, dir,
                   (O_RDONLY | O_DIRECTORY
                    | O_NOCTTY | O_NOFOLLOW | O_NONBLOCK));

  if (fd < 0)
    return false;

  dirp = fdopendir (fd);
  if (dirp == NULL)
    {
      close (fd);
      return false;
    }

  errno = 0;
  dp = readdir_ignoring_dot_and_dotdot (dirp);
  saved_errno = errno;
  closedir (dirp);
  if (dp != NULL)
    return false;
  return saved_errno == 0 ? true : false;
}

/* Factor out some of the common --help and --version processing code.  */

/* These enum values cannot possibly conflict with the option values
   ordinarily used by commands, including CHAR_MAX + 1, etc.  Avoid
   CHAR_MIN - 1, as it may equal -1, the getopt end-of-options value.  */
enum
{
  GETOPT_HELP_CHAR = (CHAR_MIN - 2),
  GETOPT_VERSION_CHAR = (CHAR_MIN - 3)
};

#define GETOPT_HELP_OPTION_DECL \
  "help", no_argument, NULL, GETOPT_HELP_CHAR
#define GETOPT_VERSION_OPTION_DECL \
  "version", no_argument, NULL, GETOPT_VERSION_CHAR
#define GETOPT_SELINUX_CONTEXT_OPTION_DECL \
  "context", optional_argument, NULL, 'Z'

#define case_GETOPT_HELP_CHAR			\
  case GETOPT_HELP_CHAR:			\
    usage (EXIT_SUCCESS);			\
    return -1;

/* Program_name must be a literal string.
   Usually it is just PROGRAM_NAME.  */
#define USAGE_BUILTIN_WARNING \
  _("\n\r" \
"NOTE: your shell may have its own version of %s, which usually supersedes\n\r" \
"the version described here.  Please refer to your shell's documentation\n\r" \
"for details about the options it supports.\n\r")

#define HELP_OPTION_DESCRIPTION \
  _("      --help     display this help and exit\n\r")
#define VERSION_OPTION_DESCRIPTION \
  _("      --version  output version information and exit\n\r")

#include "closein.h"
#include "closeout.h"

#define emit_bug_reporting_address unused__emit_bug_reporting_address
#include "version-etc.h"
#undef emit_bug_reporting_address

#include "propername.h"
/* Define away proper_name (leaving proper_name_utf8, which affects far
   fewer programs), since it's not worth the cost of adding ~17KB to
   the x86_64 text size of every single program.  This avoids a 40%
   (almost ~2MB) increase in the on-disk space utilization for the set
   of the 100 binaries. */
#define proper_name(x) (x)

#include "progname.h"

#define case_GETOPT_VERSION_CHAR(Program_name, Authors)			\
  case GETOPT_VERSION_CHAR:						\
    version_etc (stdout, Program_name, PACKAGE_NAME, Version, Authors,	\
                 (char *) NULL);					\
    // exit (EXIT_SUCCESS);						\
    break;

#ifndef MAX
# define MAX(a, b) ((a) > (b) ? (a) : (b))
#endif

#ifndef MIN
# define MIN(a,b) (((a) < (b)) ? (a) : (b))
#endif

#include "intprops.h"

#ifndef SSIZE_MAX
# define SSIZE_MAX TYPE_MAXIMUM (ssize_t)
#endif

#ifndef OFF_T_MIN
# define OFF_T_MIN TYPE_MINIMUM (off_t)
#endif

#ifndef OFF_T_MAX
# define OFF_T_MAX TYPE_MAXIMUM (off_t)
#endif

#ifndef UID_T_MAX
# define UID_T_MAX TYPE_MAXIMUM (uid_t)
#endif

#ifndef GID_T_MAX
# define GID_T_MAX TYPE_MAXIMUM (gid_t)
#endif

#ifndef PID_T_MAX
# define PID_T_MAX TYPE_MAXIMUM (pid_t)
#endif

/* Use this to suppress gcc's '...may be used before initialized' warnings. */
#ifdef lint
# define IF_LINT(Code) Code
#else
# define IF_LINT(Code) /* empty */
#endif

#ifndef __attribute__
# if __GNUC__ < 2 || (__GNUC__ == 2 && __GNUC_MINOR__ < 8)
#  define __attribute__(x) /* empty */
# endif
#endif

#ifndef ATTRIBUTE_NORETURN
# define ATTRIBUTE_NORETURN __attribute__ ((__noreturn__))
#endif

/* The warn_unused_result attribute appeared first in gcc-3.4.0 */
#undef ATTRIBUTE_WARN_UNUSED_RESULT
#if __GNUC__ < 3 || (__GNUC__ == 3 && __GNUC_MINOR__ < 4)
# define ATTRIBUTE_WARN_UNUSED_RESULT /* empty */
#else
# define ATTRIBUTE_WARN_UNUSED_RESULT __attribute__ ((__warn_unused_result__))
#endif

#ifdef __GNUC__
# define LIKELY(cond)    __builtin_expect ((cond), 1)
# define UNLIKELY(cond)  __builtin_expect ((cond), 0)
#else
# define LIKELY(cond)    (cond)
# define UNLIKELY(cond)  (cond)
#endif


#if defined strdupa
# define ASSIGN_STRDUPA(DEST, S)		\
  do { DEST = strdupa (S); } while (0)
#else
# define ASSIGN_STRDUPA(DEST, S)		\
  do						\
    {						\
      const char *s_ = (S);			\
      size_t len_ = strlen (s_) + 1;		\
      char *tmp_dest_ = alloca (len_);		\
      DEST = memcpy (tmp_dest_, s_, len_);	\
    }						\
  while (0)
#endif

#if ! HAVE_SYNC
# define sync() /* empty */
#endif

/* Compute the greatest common divisor of U and V using Euclid's
   algorithm.  U and V must be nonzero.  */

static inline size_t _GL_ATTRIBUTE_CONST
gcd (size_t u, size_t v)
{
  do
    {
      size_t t = u % v;
      u = v;
      v = t;
    }
  while (v);

  return u;
}

/* Compute the least common multiple of U and V.  U and V must be
   nonzero.  There is no overflow checking, so callers should not
   specify outlandish sizes.  */

static inline size_t _GL_ATTRIBUTE_CONST
lcm (size_t u, size_t v)
{
  return u * (v / gcd (u, v));
}

/* Return PTR, aligned upward to the next multiple of ALIGNMENT.
   ALIGNMENT must be nonzero.  The caller must arrange for ((char *)
   PTR) through ((char *) PTR + ALIGNMENT - 1) to be addressable
   locations.  */

static inline void *
ptr_align (void const *ptr, size_t alignment)
{
  char const *p0 = ptr;
  char const *p1 = p0 + alignment - 1;
  return (void *) (p1 - (size_t) p1 % alignment);
}

/* Return whether the buffer consists entirely of NULs.
   Based on memeqzero in CCAN by Rusty Russell under CC0 (Public domain).  */

static inline bool _GL_ATTRIBUTE_PURE
is_nul (void const *buf, size_t length)
{
  const unsigned char *p = buf;
/* Using possibly unaligned access for the first 16 bytes
   saves about 30-40 cycles, though it is strictly undefined behavior
   and so would need __attribute__ ((__no_sanitize_undefined__))
   to avoid -fsanitize=undefined warnings.
   Considering coreutils is mainly concerned with relatively
   large buffers, we'll just use the defined behavior.  */
#if 0 && (_STRING_ARCH_unaligned || _STRING_INLINE_unaligned)
  unsigned long word;
#else
  unsigned char word;
#endif

  if (! length)
      return true;

  /* Check len bytes not aligned on a word.  */
  while (UNLIKELY (length & (sizeof word - 1)))
    {
      if (*p)
        return false;
      p++;
      length--;
      if (! length)
        return true;
   }

  /* Check up to 16 bytes a word at a time.  */
  for (;;)
    {
      memcpy (&word, p, sizeof word);
      if (word)
        return false;
      p += sizeof word;
      length -= sizeof word;
      if (! length)
        return true;
      if (UNLIKELY (length & 15) == 0)
        break;
   }

   /* Now we know first 16 bytes are NUL, memcmp with self.  */
   return memcmp (buf, p, length) == 0;
}

/* If 10*Accum + Digit_val is larger than the maximum value for Type,
   then don't update Accum and return false to indicate it would
   overflow.  Otherwise, set Accum to that new value and return true.
   Verify at compile-time that Type is Accum's type, and that Type is
   unsigned.  Accum must be an object, so that we can take its
   address.  Accum and Digit_val may be evaluated multiple times.

   The "Added check" below is not strictly required, but it causes GCC
   to return a nonzero exit status instead of merely a warning
   diagnostic, and that is more useful.  */

#define DECIMAL_DIGIT_ACCUMULATE(Accum, Digit_val, Type)		\
  (									\
   (void) (&(Accum) == (Type *) NULL),  /* The type matches.  */	\
   (void) verify_true (! TYPE_SIGNED (Type)), /* The type is unsigned.  */ \
   (void) verify_true (sizeof (Accum) == sizeof (Type)), /* Added check.  */ \
   (((Type) -1 / 10 < (Accum)						\
     || (Type) ((Accum) * 10 + (Digit_val)) < (Accum))			\
    ? false : (((Accum) = (Accum) * 10 + (Digit_val)), true))		\
  )

static inline void
emit_stdin_note (void)
{
  fputs (_("\n\r\
With no FILE, or when FILE is -, read standard input.\n\r\
"), stdout);
}
static inline void
emit_mandatory_arg_note (void)
{
  fputs (_("\n\r\
Mandatory arguments to long options are mandatory for short options too.\n\r\
"), stdout);
}

static inline void
emit_size_note (void)
{
  fputs (_("\n\r\
The SIZE argument is an integer and optional unit (example: 10K is 10*1024).\n\r\
Units are K,M,G,T,P,E,Z,Y (powers of 1024) or KB,MB,... (powers of 1000).\n\r\
"), stdout);
}

static inline void
emit_blocksize_note (char const *program)
{
  printf (_("\n\r\
Display values are in units of the first available SIZE from --block-size,\n\r\
and the %s_BLOCK_SIZE, BLOCK_SIZE and BLOCKSIZE environment variables.\n\r\
Otherwise, units default to 1024 bytes (or 512 if POSIXLY_CORRECT is set).\n\r\
"), program);
}

static inline void
emit_backup_suffix_note (void)
{
  fputs (_("\
\n\r\
The backup suffix is '~', unless set with --suffix or SIMPLE_BACKUP_SUFFIX.\n\r\
The version control method may be selected via the --backup option or through\n\r\
the VERSION_CONTROL environment variable.  Here are the values:\n\r\
\n\r\
"), stdout);
  fputs (_("\
  none, off       never make backups (even if --backup is given)\n\r\
  numbered, t     make numbered backups\n\r\
  existing, nil   numbered if numbered backups exist, simple otherwise\n\r\
  simple, never   always make simple backups\n\r\
"), stdout);
}

static inline void
emit_ancillary_info (char const *program)
{
  struct infomap { char const *program; char const *node; } const infomap[] = {
    { "[", "test invocation" },
    { "coreutils", "Multi-call invocation" },
    { "sha224sum", "sha2 utilities" },
    { "sha256sum", "sha2 utilities" },
    { "sha384sum", "sha2 utilities" },
    { "sha512sum", "sha2 utilities" },
    { NULL, NULL }
  };

  char const *node = program;
  struct infomap const *map_prog = infomap;

  while (map_prog->program && ! STREQ (program, map_prog->program))
    map_prog++;

  if (map_prog->node)
    node = map_prog->node;

  printf (_("\n\r%s online help: <%s>\n\r"), PACKAGE_NAME, PACKAGE_URL);

  /* Don't output this redundant message for English locales.
     Note we still output for 'C' so that it gets included in the man page.  */
  const char *lc_messages = setlocale (LC_MESSAGES, NULL);
  if (lc_messages && STRNCMP_LIT (lc_messages, "en_"))
    {
      /* TRANSLATORS: Replace LANG_CODE in this URL with your language code
         <http://translationproject.org/team/LANG_CODE.html> to form one of
         the URLs at http://translationproject.org/team/.  Otherwise, replace
         the entire URL with your translation team's email address.  */
      printf (_("Report %s translation bugs to "
                "<http://translationproject.org/team/>\n\r"), program);
    }
  printf (_("Full documentation at: <%s%s>\n\r"),
          PACKAGE_URL, program);
  printf (_("or available locally via: info '(coreutils) %s%s'\n\r"),
          node, node == program ? " invocation" : "");
}

/* Use a macro rather than an inline function, as this references
   the global program_name, which causes dynamic linking issues
   in libstdbuf.so on some systems where unused functions
   are not removed by the linker.  */
#define emit_try_help() \
  do \
    { \
      fprintf (stderr, _("Try '%s --help' for more information.\n\r"), \
               program_name); \
    } \
  while (0)

#include "inttostr.h"

static inline char *
timetostr (time_t t, char *buf)
{
  return (TYPE_SIGNED (time_t)
          ? imaxtostr (t, buf)
          : umaxtostr (t, buf));
}

static inline char *
bad_cast (char const *s)
{
  return (char *) s;
}

/* Return a boolean indicating whether SB->st_size is defined.  */
static inline bool
usable_st_size (struct stat const *sb)
{
  return (S_ISREG (sb->st_mode) || S_ISLNK (sb->st_mode)
          || S_TYPEISSHM (sb) || S_TYPEISTMO (sb));
}

void usage (int status) ATTRIBUTE_NORETURN;

/* Like error(0, 0, ...), but without an implicit newline.
   Also a noop unless the global DEV_DEBUG is set.  */
#define devmsg(...)			\
  do					\
    {					\
      if (dev_debug)			\
        fprintf (stderr, __VA_ARGS__);	\
    }					\
  while (0)

#define emit_cycle_warning(file_name)	\
  do					\
    {					\
      error (0, 0, _("\
WARNING: Circular directory structure.\n\r\
This almost certainly means that you have a corrupted file system.\n\r\
NOTIFY YOUR SYSTEM MANAGER.\n\r\
The following directory is part of the cycle:\n\r  %s\n\r"), \
             quotef (file_name));	\
    }					\
  while (0)

/* Like stpncpy, but do ensure that the result is NUL-terminated,
   and do not NUL-pad out to LEN.  I.e., when strnlen (src, len) == len,
   this function writes a NUL byte into dest[len].  Thus, the length
   of the destination buffer must be at least LEN + 1.
   The DEST and SRC buffers must not overlap.  */
static inline char *
stzncpy (char *restrict dest, char const *restrict src, size_t len)
{
  char const *src_end = src + len;
  while (src < src_end && *src)
    *dest++ = *src++;
  *dest = 0;
  return dest;
}

#ifndef ARRAY_CARDINALITY
# define ARRAY_CARDINALITY(Array) (sizeof (Array) / sizeof *(Array))
#endif

/* Avoid const warnings by casting to more portable type.
   This is to cater for the incorrect const function declarations
   in selinux.h before libselinux-2.3 (May 2014).
   When version >= 2.3 is ubiquitous remove this function.  */
static inline char * se_const (char const * sctx) { return (char *) sctx; }

/* Return true if ERR is ENOTSUP or EOPNOTSUPP, otherwise false.
   This wrapper function avoids the redundant 'or'd comparison on
   systems like Linux for which they have the same value.  It also
   avoids the gcc warning to that effect.  */
static inline bool
is_ENOTSUP (int err)
{
  return err == EOPNOTSUPP || (ENOTSUP != EOPNOTSUPP && err == ENOTSUP);
}


/* How coreutils quotes filenames, to minimize use of outer quotes,
   but also provide better support for copy and paste when used.  */
#include "quotearg.h"

/* Use these to shell quote only when necessary,
   when the quoted item is already delimited with colons.  */
#define quotef(arg) \
  quotearg_n_style_colon (0, shell_escape_quoting_style, arg)
#define quotef_n(n, arg) \
  quotearg_n_style_colon (n, shell_escape_quoting_style, arg)

/* Use these when there are spaces around the file name,
   in the error message.  */
#define quoteaf(arg) \
  quotearg_style (shell_escape_always_quoting_style, arg)
#define quoteaf_n(n, arg) \
  quotearg_n_style (n, shell_escape_always_quoting_style, arg)
