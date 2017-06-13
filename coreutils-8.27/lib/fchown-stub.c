#include "config.h"

#include <sys/types.h>
#include <errno.h>

/* A trivial substitute for 'fchown'.

   DJGPP 2.03 and earlier (and perhaps later) don't have 'fchown',
   so we pretend no-one has permission for this operation. */

int
fchown (int fd, uid_t uid, gid_t gid)
{
  errno = EPERM;
  return -1;
}
