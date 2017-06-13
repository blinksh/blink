/* A GNU-like <dirent.h>.
   Copyright (C) 2006-2017 Free Software Foundation, Inc.

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

#ifndef _@GUARD_PREFIX@_DIRENT_H

#if __GNUC__ >= 3
@PRAGMA_SYSTEM_HEADER@
#endif
@PRAGMA_COLUMNS@

/* The include_next requires a split double-inclusion guard.  */
#if @HAVE_DIRENT_H@
# @INCLUDE_NEXT@ @NEXT_DIRENT_H@
#endif

#ifndef _@GUARD_PREFIX@_DIRENT_H
#define _@GUARD_PREFIX@_DIRENT_H

/* Get ino_t.  Needed on some systems, including glibc 2.8.  */
#include <sys/types.h>

#if !@HAVE_DIRENT_H@
/* Define types DIR and 'struct dirent'.  */
# if !GNULIB_defined_struct_dirent
struct dirent
{
  char d_type;
  char d_name[1];
};
/* Possible values for 'd_type'.  */
#  define DT_UNKNOWN 0
#  define DT_FIFO    1          /* FIFO */
#  define DT_CHR     2          /* character device */
#  define DT_DIR     4          /* directory */
#  define DT_BLK     6          /* block device */
#  define DT_REG     8          /* regular file */
#  define DT_LNK    10          /* symbolic link */
#  define DT_SOCK   12          /* socket */
#  define DT_WHT    14          /* whiteout */
typedef struct gl_directory DIR;
#  define GNULIB_defined_struct_dirent 1
# endif
#endif

/* The __attribute__ feature is available in gcc versions 2.5 and later.
   The attribute __pure__ was added in gcc 2.96.  */
#if __GNUC__ > 2 || (__GNUC__ == 2 && __GNUC_MINOR__ >= 96)
# define _GL_ATTRIBUTE_PURE __attribute__ ((__pure__))
#else
# define _GL_ATTRIBUTE_PURE /* empty */
#endif

/* The definitions of _GL_FUNCDECL_RPL etc. are copied here.  */

/* The definition of _GL_ARG_NONNULL is copied here.  */

/* The definition of _GL_WARN_ON_USE is copied here.  */


/* Declare overridden functions.  */

#if @GNULIB_OPENDIR@
# if @REPLACE_OPENDIR@
#  if !(defined __cplusplus && defined GNULIB_NAMESPACE)
#   undef opendir
#   define opendir rpl_opendir
#   define GNULIB_defined_opendir 1
#  endif
_GL_FUNCDECL_RPL (opendir, DIR *, (const char *dir_name) _GL_ARG_NONNULL ((1)));
_GL_CXXALIAS_RPL (opendir, DIR *, (const char *dir_name));
# else
#  if !@HAVE_OPENDIR@
_GL_FUNCDECL_SYS (opendir, DIR *, (const char *dir_name) _GL_ARG_NONNULL ((1)));
#  endif
_GL_CXXALIAS_SYS (opendir, DIR *, (const char *dir_name));
# endif
_GL_CXXALIASWARN (opendir);
#elif defined GNULIB_POSIXCHECK
# undef opendir
# if HAVE_RAW_DECL_OPENDIR
_GL_WARN_ON_USE (opendir, "opendir is not portable - "
                 "use gnulib module opendir for portability");
# endif
#endif

#if @GNULIB_READDIR@
# if !@HAVE_READDIR@
_GL_FUNCDECL_SYS (readdir, struct dirent *, (DIR *dirp) _GL_ARG_NONNULL ((1)));
# endif
_GL_CXXALIAS_SYS (readdir, struct dirent *, (DIR *dirp));
_GL_CXXALIASWARN (readdir);
#elif defined GNULIB_POSIXCHECK
# undef readdir
# if HAVE_RAW_DECL_READDIR
_GL_WARN_ON_USE (readdir, "readdir is not portable - "
                 "use gnulib module readdir for portability");
# endif
#endif

#if @GNULIB_REWINDDIR@
# if !@HAVE_REWINDDIR@
_GL_FUNCDECL_SYS (rewinddir, void, (DIR *dirp) _GL_ARG_NONNULL ((1)));
# endif
_GL_CXXALIAS_SYS (rewinddir, void, (DIR *dirp));
_GL_CXXALIASWARN (rewinddir);
#elif defined GNULIB_POSIXCHECK
# undef rewinddir
# if HAVE_RAW_DECL_REWINDDIR
_GL_WARN_ON_USE (rewinddir, "rewinddir is not portable - "
                 "use gnulib module rewinddir for portability");
# endif
#endif

#if @GNULIB_CLOSEDIR@
# if @REPLACE_CLOSEDIR@
#  if !(defined __cplusplus && defined GNULIB_NAMESPACE)
#   undef closedir
#   define closedir rpl_closedir
#   define GNULIB_defined_closedir 1
#  endif
_GL_FUNCDECL_RPL (closedir, int, (DIR *dirp) _GL_ARG_NONNULL ((1)));
_GL_CXXALIAS_RPL (closedir, int, (DIR *dirp));
# else
#  if !@HAVE_CLOSEDIR@
_GL_FUNCDECL_SYS (closedir, int, (DIR *dirp) _GL_ARG_NONNULL ((1)));
#  endif
_GL_CXXALIAS_SYS (closedir, int, (DIR *dirp));
# endif
_GL_CXXALIASWARN (closedir);
#elif defined GNULIB_POSIXCHECK
# undef closedir
# if HAVE_RAW_DECL_CLOSEDIR
_GL_WARN_ON_USE (closedir, "closedir is not portable - "
                 "use gnulib module closedir for portability");
# endif
#endif

#if @GNULIB_DIRFD@
/* Return the file descriptor associated with the given directory stream,
   or -1 if none exists.  */
# if @REPLACE_DIRFD@
#  if !(defined __cplusplus && defined GNULIB_NAMESPACE)
#   undef dirfd
#   define dirfd rpl_dirfd
#  endif
_GL_FUNCDECL_RPL (dirfd, int, (DIR *) _GL_ARG_NONNULL ((1)));
_GL_CXXALIAS_RPL (dirfd, int, (DIR *));

#  ifdef __KLIBC__
/* Gnulib internal hooks needed to maintain the dirfd metadata.  */
_GL_EXTERN_C int _gl_register_dirp_fd (int fd, DIR *dirp)
     _GL_ARG_NONNULL ((2));
_GL_EXTERN_C void _gl_unregister_dirp_fd (int fd);
#  endif
# else
#  if defined __cplusplus && defined GNULIB_NAMESPACE && defined dirfd
    /* dirfd is defined as a macro and not as a function.
       Turn it into a function and get rid of the macro.  */
static inline int (dirfd) (DIR *dp) { return dirfd (dp); }
#   undef dirfd
#  endif
#  if !(@HAVE_DECL_DIRFD@ || defined dirfd)
_GL_FUNCDECL_SYS (dirfd, int, (DIR *) _GL_ARG_NONNULL ((1)));
#  endif
_GL_CXXALIAS_SYS (dirfd, int, (DIR *));
# endif
_GL_CXXALIASWARN (dirfd);
#elif defined GNULIB_POSIXCHECK
# undef dirfd
# if HAVE_RAW_DECL_DIRFD
_GL_WARN_ON_USE (dirfd, "dirfd is unportable - "
                 "use gnulib module dirfd for portability");
# endif
#endif

#if @GNULIB_FDOPENDIR@
/* Open a directory stream visiting the given directory file
   descriptor.  Return NULL and set errno if fd is not visiting a
   directory.  On success, this function consumes fd (it will be
   implicitly closed either by this function or by a subsequent
   closedir).  */
# if @REPLACE_FDOPENDIR@
#  if !(defined __cplusplus && defined GNULIB_NAMESPACE)
#   undef fdopendir
#   define fdopendir rpl_fdopendir
#  endif
_GL_FUNCDECL_RPL (fdopendir, DIR *, (int fd));
_GL_CXXALIAS_RPL (fdopendir, DIR *, (int fd));
# else
#  if !@HAVE_FDOPENDIR@ || !@HAVE_DECL_FDOPENDIR@
_GL_FUNCDECL_SYS (fdopendir, DIR *, (int fd));
#  endif
_GL_CXXALIAS_SYS (fdopendir, DIR *, (int fd));
# endif
_GL_CXXALIASWARN (fdopendir);
#elif defined GNULIB_POSIXCHECK
# undef fdopendir
# if HAVE_RAW_DECL_FDOPENDIR
_GL_WARN_ON_USE (fdopendir, "fdopendir is unportable - "
                 "use gnulib module fdopendir for portability");
# endif
#endif

#if @GNULIB_SCANDIR@
/* Scan the directory DIR, calling FILTER on each directory entry.
   Entries for which FILTER returns nonzero are individually malloc'd,
   sorted using qsort with CMP, and collected in a malloc'd array in
   *NAMELIST.  Returns the number of entries selected, or -1 on error.  */
# if !@HAVE_SCANDIR@
_GL_FUNCDECL_SYS (scandir, int,
                  (const char *dir, struct dirent ***namelist,
                   int (*filter) (const struct dirent *),
                   int (*cmp) (const struct dirent **, const struct dirent **))
                  _GL_ARG_NONNULL ((1, 2, 4)));
# endif
/* Need to cast, because on glibc systems, the fourth parameter is
                        int (*cmp) (const void *, const void *).  */
_GL_CXXALIAS_SYS_CAST (scandir, int,
                       (const char *dir, struct dirent ***namelist,
                        int (*filter) (const struct dirent *),
                        int (*cmp) (const struct dirent **, const struct dirent **)));
_GL_CXXALIASWARN (scandir);
#elif defined GNULIB_POSIXCHECK
# undef scandir
# if HAVE_RAW_DECL_SCANDIR
_GL_WARN_ON_USE (scandir, "scandir is unportable - "
                 "use gnulib module scandir for portability");
# endif
#endif

#if @GNULIB_ALPHASORT@
/* Compare two 'struct dirent' entries alphabetically.  */
# if !@HAVE_ALPHASORT@
_GL_FUNCDECL_SYS (alphasort, int,
                  (const struct dirent **, const struct dirent **)
                  _GL_ATTRIBUTE_PURE
                  _GL_ARG_NONNULL ((1, 2)));
# endif
/* Need to cast, because on glibc systems, the parameters are
                       (const void *, const void *).  */
_GL_CXXALIAS_SYS_CAST (alphasort, int,
                       (const struct dirent **, const struct dirent **));
_GL_CXXALIASWARN (alphasort);
#elif defined GNULIB_POSIXCHECK
# undef alphasort
# if HAVE_RAW_DECL_ALPHASORT
_GL_WARN_ON_USE (alphasort, "alphasort is unportable - "
                 "use gnulib module alphasort for portability");
# endif
#endif


#endif /* _@GUARD_PREFIX@_DIRENT_H */
#endif /* _@GUARD_PREFIX@_DIRENT_H */
