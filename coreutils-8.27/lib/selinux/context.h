/* DO NOT EDIT! GENERATED AUTOMATICALLY! */
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
/* _GL_UNUSED_PARAMETER is a marker that can be appended to function parameter
   declarations for parameters that are not used.  This helps to reduce
   warnings, such as from GCC -Wunused-parameter.  The syntax is as follows:
       type param _GL_UNUSED_PARAMETER
   or more generally
       param_decl _GL_UNUSED_PARAMETER
   For example:
       int param _GL_UNUSED_PARAMETER
       int *(*param)(void) _GL_UNUSED_PARAMETER
   Other possible, but obscure and discouraged syntaxes:
       int _GL_UNUSED_PARAMETER *(*param)(void)
       _GL_UNUSED_PARAMETER int *(*param)(void)
 */
#ifndef _GL_UNUSED_PARAMETER
# if __GNUC__ >= 3 || (__GNUC__ == 2 && __GNUC_MINOR__ >= 7)
#  define _GL_UNUSED_PARAMETER __attribute__ ((__unused__))
# else
#  define _GL_UNUSED_PARAMETER
# endif
#endif

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
