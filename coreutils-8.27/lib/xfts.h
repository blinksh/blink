#include <stdbool.h>
#include "fts_.h"

FTS *
xfts_open (char * const *, int options,
           int (*) (const FTSENT **, const FTSENT **));

bool
cycle_warning_required (FTS const *fts, FTSENT const *ent)
  _GL_ATTRIBUTE_PURE;
