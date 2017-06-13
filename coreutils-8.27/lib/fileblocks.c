/* Convert file size to number of blocks on System V-like machines.

   Copyright (C) 1990, 1997-1999, 2004-2006, 2009-2017 Free Software
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

/* Written by Brian L. Matthews, blm@6sceng.UUCP. */

#include "config.h"

#include <sys/types.h>

#if HAVE_SYS_PARAM_H
# include <sys/param.h>
#endif

#if !HAVE_STRUCT_STAT_ST_BLOCKS && !defined _POSIX_SOURCE && defined BSIZE

# include <unistd.h>

# ifndef NINDIR

#  if defined __DJGPP__
typedef long daddr_t; /* for disk address */
#  endif

/* Some SysV's, like Irix, seem to lack this.  Hope it's correct. */
/* Number of inode pointers per indirect block. */
#  define NINDIR (BSIZE / sizeof (daddr_t))
# endif /* !NINDIR */

/* Number of direct block addresses in an inode. */
# define NDIR   10

/* Return the number of 512-byte blocks in a file of SIZE bytes. */

off_t
st_blocks (off_t size)
{
  off_t datablks = size / 512 + (size % 512 != 0);
  off_t indrblks = 0;

  if (datablks > NDIR)
    {
      indrblks = (datablks - NDIR - 1) / NINDIR + 1;

      if (datablks > NDIR + NINDIR)
        {
          indrblks += (datablks - NDIR - NINDIR - 1) / (NINDIR * NINDIR) + 1;

          if (datablks > NDIR + NINDIR + NINDIR * NINDIR)
            indrblks++;
        }
    }

  return datablks + indrblks;
}
#else
/* This declaration is solely to ensure that after preprocessing
   this file is never empty.  */
typedef int textutils_fileblocks_unused;
#endif
