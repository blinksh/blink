/* Declare an access pattern hint for files.
   Copyright (C) 2010-2017 Free Software Foundation, Inc.

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

#include "config.h"
#include <stdio.h>
#include <fcntl.h>
#include <sys/types.h>

/* There are a few hints one can provide, which have the
   following characteristics on Linux 2.6.31 at least.

   POSIX_FADV_SEQUENTIAL
     Doubles the size of read ahead done for file
   POSIX_FADV_WILLNEED
     _synchronously_ prepopulate the buffer cache with the file
   POSIX_FADV_NOREUSE
     Could lower priority of data in buffer caches,
     but currently does nothing.
   POSIX_FADV_DONTNEED
     Drop the file from cache.
     Note this is automatically done when files are unlinked.

   We use this enum "type" both to make it explicit that
   these options are mutually exclusive, and to discourage
   the passing of the possibly undefined POSIX_FADV_... values.
   Note we could #undef the POSIX_FADV_ values, but that would
   preclude using the posix_fadvise() function with its standard
   constants. Using posix_fadvise() might be required if the return
   value is needed, but it must be guarded by appropriate #ifdefs.  */

#if HAVE_POSIX_FADVISE
typedef enum {
  FADVISE_NORMAL =     POSIX_FADV_NORMAL,
  FADVISE_SEQUENTIAL = POSIX_FADV_SEQUENTIAL,
  FADVISE_NOREUSE =    POSIX_FADV_NOREUSE,
  FADVISE_DONTNEED =   POSIX_FADV_DONTNEED,
  FADVISE_WILLNEED =   POSIX_FADV_WILLNEED,
  FADVISE_RANDOM =     POSIX_FADV_RANDOM
} fadvice_t;
#else
typedef enum {
  FADVISE_NORMAL,
  FADVISE_SEQUENTIAL,
  FADVISE_NOREUSE,
  FADVISE_DONTNEED,
  FADVISE_WILLNEED,
  FADVISE_RANDOM
} fadvice_t;
#endif

/* We ignore any errors as these hints are only advisory.
   There is the chance one can pass invalid ADVICE, which will
   not be indicated, but given the simplicity of the interface
   this is unlikely.  Also not returning errors allows the
   unconditional passing of descriptors to non standard files,
   which will just be ignored if unsupported.  */

void fdadvise (int fd, off_t offset, off_t len, fadvice_t advice);
void fadvise (FILE *fp, fadvice_t advice);
