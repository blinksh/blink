#ifndef SELINUX_CONTEXT_H
# define SELINUX_CONTEXT_H

# include <errno.h>

#ifndef _GL_INLINE_HEADER_BEGIN
 #error "Please include config.h first."
#endif
_GL_INLINE_HEADER_BEGIN
#ifndef SE_CONTEXT_INLINE
# define SE_CONTEXT_INLINE _GL_INLINE
#endif

/* The definition of _GL_UNUSED_PARAMETER is copied here.  */

typedef int context_t;
SE_CONTEXT_INLINE context_t context_new (char const *s _GL_UNUSED_PARAMETER)
  { errno = ENOTSUP; return 0; }
SE_CONTEXT_INLINE char *context_str (context_t con _GL_UNUSED_PARAMETER)
  { errno = ENOTSUP; return (void *) 0; }
SE_CONTEXT_INLINE void context_free (context_t c _GL_UNUSED_PARAMETER) {}

SE_CONTEXT_INLINE int context_user_set (context_t sc _GL_UNUSED_PARAMETER,
                                        char const *s _GL_UNUSED_PARAMETER)
  { errno = ENOTSUP; return -1; }
SE_CONTEXT_INLINE int context_role_set (context_t sc _GL_UNUSED_PARAMETER,
                                        char const *s _GL_UNUSED_PARAMETER)
  { errno = ENOTSUP; return -1; }
SE_CONTEXT_INLINE int context_range_set (context_t sc _GL_UNUSED_PARAMETER,
                                         char const *s _GL_UNUSED_PARAMETER)
  { errno = ENOTSUP; return -1; }
SE_CONTEXT_INLINE int context_type_set (context_t sc _GL_UNUSED_PARAMETER,
                                        char const *s _GL_UNUSED_PARAMETER)
  { errno = ENOTSUP; return -1; }
SE_CONTEXT_INLINE char *context_type_get (context_t sc _GL_UNUSED_PARAMETER)
  { errno = ENOTSUP; return (void *) 0; }
SE_CONTEXT_INLINE char *context_range_get (context_t sc _GL_UNUSED_PARAMETER)
  { errno = ENOTSUP; return (void *) 0; }
SE_CONTEXT_INLINE char *context_role_get (context_t sc _GL_UNUSED_PARAMETER)
  { errno = ENOTSUP; return (void *) 0; }
SE_CONTEXT_INLINE char *context_user_get (context_t sc _GL_UNUSED_PARAMETER)
  { errno = ENOTSUP; return (void *) 0; }

_GL_INLINE_HEADER_END

#endif
