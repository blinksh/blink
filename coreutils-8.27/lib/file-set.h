#include <sys/types.h>
#include <sys/stat.h>
#include <stdbool.h>

#include "hash.h"

extern void record_file (Hash_table *ht, char const *file,
                         struct stat const *stats)
#if defined __GNUC__ && ((__GNUC__ == 3 && __GNUC_MINOR__ >= 3) || __GNUC__ > 3)
  __attribute__ ((nonnull (2, 3)))
#endif
;

extern bool seen_file (Hash_table const *ht, char const *file,
                       struct stat const *stats);
