#ifndef HASH_TRIPLE_H
#define HASH_TRIPLE_H

#include <sys/types.h>
#include <sys/stat.h>
#include <stdbool.h>

/* Describe a just-created or just-renamed destination file.  */
struct F_triple
{
  char *name;
  ino_t st_ino;
  dev_t st_dev;
};

extern size_t triple_hash (void const *x, size_t table_size) _GL_ATTRIBUTE_PURE;
extern size_t triple_hash_no_name (void const *x, size_t table_size)
  _GL_ATTRIBUTE_PURE;
extern bool triple_compare (void const *x, void const *y);
extern bool triple_compare_ino_str (void const *x, void const *y)
  _GL_ATTRIBUTE_PURE;
extern void triple_free (void *x);

#endif
