#ifndef _GL_DI_SET_H
# define _GL_DI_SET_H

# include <sys/types.h>

# undef _GL_ATTRIBUTE_NONNULL
# if __GNUC__ == 3 && __GNUC_MINOR__ >= 3 || 3 < __GNUC__
#  define _GL_ATTRIBUTE_NONNULL(m) __attribute__ ((__nonnull__ (m)))
# else
#  define _GL_ATTRIBUTE_NONNULL(m)
# endif

struct di_set *di_set_alloc (void);
int di_set_insert (struct di_set *, dev_t, ino_t) _GL_ATTRIBUTE_NONNULL (1);
void di_set_free (struct di_set *) _GL_ATTRIBUTE_NONNULL (1);
int di_set_lookup (struct di_set *dis, dev_t dev, ino_t ino)
  _GL_ATTRIBUTE_NONNULL (1);

#endif
