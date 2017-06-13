#ifndef _GL_INO_MAP_H
# define _GL_INO_MAP_H

# include <sys/types.h>

# undef _GL_ATTRIBUTE_NONNULL
# if __GNUC__ == 3 && __GNUC_MINOR__ >= 3 || 3 < __GNUC__
#  define _GL_ATTRIBUTE_NONNULL(m) __attribute__ ((__nonnull__ (m)))
# else
#  define _GL_ATTRIBUTE_NONNULL(m)
# endif

# define INO_MAP_INSERT_FAILURE ((size_t) -1)

struct ino_map *ino_map_alloc (size_t);
void ino_map_free (struct ino_map *) _GL_ATTRIBUTE_NONNULL (1);
size_t ino_map_insert (struct ino_map *, ino_t) _GL_ATTRIBUTE_NONNULL (1);

#endif
