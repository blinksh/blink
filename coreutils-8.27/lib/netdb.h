/* DO NOT EDIT! GENERATED AUTOMATICALLY! */
/* Provide a netdb.h header file for systems lacking it (read: MinGW).
   Copyright (C) 2008-2017 Free Software Foundation, Inc.
   Written by Simon Josefsson.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, see <http://www.gnu.org/licenses/>.  */

/* This file is supposed to be used on platforms that lack <netdb.h>.
   It is intended to provide definitions and prototypes needed by an
   application.  */

#ifndef _GL_NETDB_H

#if __GNUC__ >= 3
#pragma GCC system_header
#endif


#if 1

/* The include_next requires a split double-inclusion guard.  */
# include_next <netdb.h>

#endif

#ifndef _GL_NETDB_H
#define _GL_NETDB_H

/* Get <netdb.h> definitions such as 'socklen_t' on IRIX 6.5 and OSF/1 4.0 and
   'struct hostent' on MinGW.  */
#include <sys/socket.h>

/* The definitions of _GL_FUNCDECL_RPL etc. are copied here.  */
#ifndef _GL_CXXDEFS_H
#define _GL_CXXDEFS_H

/* Begin/end the GNULIB_NAMESPACE namespace.  */
#if defined __cplusplus && defined GNULIB_NAMESPACE
# define _GL_BEGIN_NAMESPACE namespace GNULIB_NAMESPACE {
# define _GL_END_NAMESPACE }
#else
# define _GL_BEGIN_NAMESPACE
# define _GL_END_NAMESPACE
#endif

/* The three most frequent use cases of these macros are:

   * For providing a substitute for a function that is missing on some
     platforms, but is declared and works fine on the platforms on which
     it exists:

       #if @GNULIB_FOO@
       # if !@HAVE_FOO@
       _GL_FUNCDECL_SYS (foo, ...);
       # endif
       _GL_CXXALIAS_SYS (foo, ...);
       _GL_CXXALIASWARN (foo);
       #elif defined GNULIB_POSIXCHECK
       ...
       #endif

   * For providing a replacement for a function that exists on all platforms,
     but is broken/insufficient and needs to be replaced on some platforms:

       #if @GNULIB_FOO@
       # if @REPLACE_FOO@
       #  if !(defined __cplusplus && defined GNULIB_NAMESPACE)
       #   undef foo
       #   define foo rpl_foo
       #  endif
       _GL_FUNCDECL_RPL (foo, ...);
       _GL_CXXALIAS_RPL (foo, ...);
       # else
       _GL_CXXALIAS_SYS (foo, ...);
       # endif
       _GL_CXXALIASWARN (foo);
       #elif defined GNULIB_POSIXCHECK
       ...
       #endif

   * For providing a replacement for a function that exists on some platforms
     but is broken/insufficient and needs to be replaced on some of them and
     is additionally either missing or undeclared on some other platforms:

       #if @GNULIB_FOO@
       # if @REPLACE_FOO@
       #  if !(defined __cplusplus && defined GNULIB_NAMESPACE)
       #   undef foo
       #   define foo rpl_foo
       #  endif
       _GL_FUNCDECL_RPL (foo, ...);
       _GL_CXXALIAS_RPL (foo, ...);
       # else
       #  if !@HAVE_FOO@   or   if !@HAVE_DECL_FOO@
       _GL_FUNCDECL_SYS (foo, ...);
       #  endif
       _GL_CXXALIAS_SYS (foo, ...);
       # endif
       _GL_CXXALIASWARN (foo);
       #elif defined GNULIB_POSIXCHECK
       ...
       #endif
*/

/* _GL_EXTERN_C declaration;
   performs the declaration with C linkage.  */
#if defined __cplusplus
# define _GL_EXTERN_C extern "C"
#else
# define _GL_EXTERN_C extern
#endif

/* _GL_FUNCDECL_RPL (func, rettype, parameters_and_attributes);
   declares a replacement function, named rpl_func, with the given prototype,
   consisting of return type, parameters, and attributes.
   Example:
     _GL_FUNCDECL_RPL (open, int, (const char *filename, int flags, ...)
                                  _GL_ARG_NONNULL ((1)));
 */
#define _GL_FUNCDECL_RPL(func,rettype,parameters_and_attributes) \
  _GL_FUNCDECL_RPL_1 (rpl_##func, rettype, parameters_and_attributes)
#define _GL_FUNCDECL_RPL_1(rpl_func,rettype,parameters_and_attributes) \
  _GL_EXTERN_C rettype rpl_func parameters_and_attributes

/* _GL_FUNCDECL_SYS (func, rettype, parameters_and_attributes);
   declares the system function, named func, with the given prototype,
   consisting of return type, parameters, and attributes.
   Example:
     _GL_FUNCDECL_SYS (open, int, (const char *filename, int flags, ...)
                                  _GL_ARG_NONNULL ((1)));
 */
#define _GL_FUNCDECL_SYS(func,rettype,parameters_and_attributes) \
  _GL_EXTERN_C rettype func parameters_and_attributes

/* _GL_CXXALIAS_RPL (func, rettype, parameters);
   declares a C++ alias called GNULIB_NAMESPACE::func
   that redirects to rpl_func, if GNULIB_NAMESPACE is defined.
   Example:
     _GL_CXXALIAS_RPL (open, int, (const char *filename, int flags, ...));

   Wrapping rpl_func in an object with an inline conversion operator
   avoids a reference to rpl_func unless GNULIB_NAMESPACE::func is
   actually used in the program.  */
#define _GL_CXXALIAS_RPL(func,rettype,parameters) \
  _GL_CXXALIAS_RPL_1 (func, rpl_##func, rettype, parameters)
#if defined __cplusplus && defined GNULIB_NAMESPACE
# define _GL_CXXALIAS_RPL_1(func,rpl_func,rettype,parameters) \
    namespace GNULIB_NAMESPACE                                \
    {                                                         \
      static const struct _gl_ ## func ## _wrapper            \
      {                                                       \
        typedef rettype (*type) parameters;                   \
                                                              \
        inline operator type () const                         \
        {                                                     \
          return ::rpl_func;                                  \
        }                                                     \
      } func = {};                                            \
    }                                                         \
    _GL_EXTERN_C int _gl_cxxalias_dummy
#else
# define _GL_CXXALIAS_RPL_1(func,rpl_func,rettype,parameters) \
    _GL_EXTERN_C int _gl_cxxalias_dummy
#endif

/* _GL_CXXALIAS_RPL_CAST_1 (func, rpl_func, rettype, parameters);
   is like  _GL_CXXALIAS_RPL_1 (func, rpl_func, rettype, parameters);
   except that the C function rpl_func may have a slightly different
   declaration.  A cast is used to silence the "invalid conversion" error
   that would otherwise occur.  */
#if defined __cplusplus && defined GNULIB_NAMESPACE
# define _GL_CXXALIAS_RPL_CAST_1(func,rpl_func,rettype,parameters) \
    namespace GNULIB_NAMESPACE                                     \
    {                                                              \
      static const struct _gl_ ## func ## _wrapper                 \
      {                                                            \
        typedef rettype (*type) parameters;                        \
                                                                   \
        inline operator type () const                              \
        {                                                          \
          return reinterpret_cast<type>(::rpl_func);               \
        }                                                          \
      } func = {};                                                 \
    }                                                              \
    _GL_EXTERN_C int _gl_cxxalias_dummy
#else
# define _GL_CXXALIAS_RPL_CAST_1(func,rpl_func,rettype,parameters) \
    _GL_EXTERN_C int _gl_cxxalias_dummy
#endif

/* _GL_CXXALIAS_SYS (func, rettype, parameters);
   declares a C++ alias called GNULIB_NAMESPACE::func
   that redirects to the system provided function func, if GNULIB_NAMESPACE
   is defined.
   Example:
     _GL_CXXALIAS_SYS (open, int, (const char *filename, int flags, ...));

   Wrapping func in an object with an inline conversion operator
   avoids a reference to func unless GNULIB_NAMESPACE::func is
   actually used in the program.  */
#if defined __cplusplus && defined GNULIB_NAMESPACE
# define _GL_CXXALIAS_SYS(func,rettype,parameters)            \
    namespace GNULIB_NAMESPACE                                \
    {                                                         \
      static const struct _gl_ ## func ## _wrapper            \
      {                                                       \
        typedef rettype (*type) parameters;                   \
                                                              \
        inline operator type () const                         \
        {                                                     \
          return ::func;                                      \
        }                                                     \
      } func = {};                                            \
    }                                                         \
    _GL_EXTERN_C int _gl_cxxalias_dummy
#else
# define _GL_CXXALIAS_SYS(func,rettype,parameters) \
    _GL_EXTERN_C int _gl_cxxalias_dummy
#endif

/* _GL_CXXALIAS_SYS_CAST (func, rettype, parameters);
   is like  _GL_CXXALIAS_SYS (func, rettype, parameters);
   except that the C function func may have a slightly different declaration.
   A cast is used to silence the "invalid conversion" error that would
   otherwise occur.  */
#if defined __cplusplus && defined GNULIB_NAMESPACE
# define _GL_CXXALIAS_SYS_CAST(func,rettype,parameters) \
    namespace GNULIB_NAMESPACE                          \
    {                                                   \
      static const struct _gl_ ## func ## _wrapper      \
      {                                                 \
        typedef rettype (*type) parameters;             \
                                                        \
        inline operator type () const                   \
        {                                               \
          return reinterpret_cast<type>(::func);        \
        }                                               \
      } func = {};                                      \
    }                                                   \
    _GL_EXTERN_C int _gl_cxxalias_dummy
#else
# define _GL_CXXALIAS_SYS_CAST(func,rettype,parameters) \
    _GL_EXTERN_C int _gl_cxxalias_dummy
#endif

/* _GL_CXXALIAS_SYS_CAST2 (func, rettype, parameters, rettype2, parameters2);
   is like  _GL_CXXALIAS_SYS (func, rettype, parameters);
   except that the C function is picked among a set of overloaded functions,
   namely the one with rettype2 and parameters2.  Two consecutive casts
   are used to silence the "cannot find a match" and "invalid conversion"
   errors that would otherwise occur.  */
#if defined __cplusplus && defined GNULIB_NAMESPACE
  /* The outer cast must be a reinterpret_cast.
     The inner cast: When the function is defined as a set of overloaded
     functions, it works as a static_cast<>, choosing the designated variant.
     When the function is defined as a single variant, it works as a
     reinterpret_cast<>. The parenthesized cast syntax works both ways.  */
# define _GL_CXXALIAS_SYS_CAST2(func,rettype,parameters,rettype2,parameters2) \
    namespace GNULIB_NAMESPACE                                                \
    {                                                                         \
      static const struct _gl_ ## func ## _wrapper                            \
      {                                                                       \
        typedef rettype (*type) parameters;                                   \
                                                                              \
        inline operator type () const                                         \
        {                                                                     \
          return reinterpret_cast<type>((rettype2 (*) parameters2)(::func));  \
        }                                                                     \
      } func = {};                                                            \
    }                                                                         \
    _GL_EXTERN_C int _gl_cxxalias_dummy
#else
# define _GL_CXXALIAS_SYS_CAST2(func,rettype,parameters,rettype2,parameters2) \
    _GL_EXTERN_C int _gl_cxxalias_dummy
#endif

/* _GL_CXXALIASWARN (func);
   causes a warning to be emitted when ::func is used but not when
   GNULIB_NAMESPACE::func is used.  func must be defined without overloaded
   variants.  */
#if defined __cplusplus && defined GNULIB_NAMESPACE
# define _GL_CXXALIASWARN(func) \
   _GL_CXXALIASWARN_1 (func, GNULIB_NAMESPACE)
# define _GL_CXXALIASWARN_1(func,namespace) \
   _GL_CXXALIASWARN_2 (func, namespace)
/* To work around GCC bug <http://gcc.gnu.org/bugzilla/show_bug.cgi?id=43881>,
   we enable the warning only when not optimizing.  */
# if !__OPTIMIZE__
#  define _GL_CXXALIASWARN_2(func,namespace) \
    _GL_WARN_ON_USE (func, \
                     "The symbol ::" #func " refers to the system function. " \
                     "Use " #namespace "::" #func " instead.")
# elif __GNUC__ >= 3 && GNULIB_STRICT_CHECKING
#  define _GL_CXXALIASWARN_2(func,namespace) \
     extern __typeof__ (func) func
# else
#  define _GL_CXXALIASWARN_2(func,namespace) \
     _GL_EXTERN_C int _gl_cxxalias_dummy
# endif
#else
# define _GL_CXXALIASWARN(func) \
    _GL_EXTERN_C int _gl_cxxalias_dummy
#endif

/* _GL_CXXALIASWARN1 (func, rettype, parameters_and_attributes);
   causes a warning to be emitted when the given overloaded variant of ::func
   is used but not when GNULIB_NAMESPACE::func is used.  */
#if defined __cplusplus && defined GNULIB_NAMESPACE
# define _GL_CXXALIASWARN1(func,rettype,parameters_and_attributes) \
   _GL_CXXALIASWARN1_1 (func, rettype, parameters_and_attributes, \
                        GNULIB_NAMESPACE)
# define _GL_CXXALIASWARN1_1(func,rettype,parameters_and_attributes,namespace) \
   _GL_CXXALIASWARN1_2 (func, rettype, parameters_and_attributes, namespace)
/* To work around GCC bug <http://gcc.gnu.org/bugzilla/show_bug.cgi?id=43881>,
   we enable the warning only when not optimizing.  */
# if !__OPTIMIZE__
#  define _GL_CXXALIASWARN1_2(func,rettype,parameters_and_attributes,namespace) \
    _GL_WARN_ON_USE_CXX (func, rettype, parameters_and_attributes, \
                         "The symbol ::" #func " refers to the system function. " \
                         "Use " #namespace "::" #func " instead.")
# elif __GNUC__ >= 3 && GNULIB_STRICT_CHECKING
#  define _GL_CXXALIASWARN1_2(func,rettype,parameters_and_attributes,namespace) \
     extern __typeof__ (func) func
# else
#  define _GL_CXXALIASWARN1_2(func,rettype,parameters_and_attributes,namespace) \
     _GL_EXTERN_C int _gl_cxxalias_dummy
# endif
#else
# define _GL_CXXALIASWARN1(func,rettype,parameters_and_attributes) \
    _GL_EXTERN_C int _gl_cxxalias_dummy
#endif

#endif /* _GL_CXXDEFS_H */

/* The definition of _GL_ARG_NONNULL is copied here.  */
/* _GL_ARG_NONNULL((n,...,m)) tells the compiler and static analyzer tools
   that the values passed as arguments n, ..., m must be non-NULL pointers.
   n = 1 stands for the first argument, n = 2 for the second argument etc.  */
#ifndef _GL_ARG_NONNULL
# if (__GNUC__ == 3 && __GNUC_MINOR__ >= 3) || __GNUC__ > 3
#  define _GL_ARG_NONNULL(params) __attribute__ ((__nonnull__ params))
# else
#  define _GL_ARG_NONNULL(params)
# endif
#endif

/* The definition of _GL_WARN_ON_USE is copied here.  */
#ifndef _GL_WARN_ON_USE

# if 4 < __GNUC__ || (__GNUC__ == 4 && 3 <= __GNUC_MINOR__)
/* A compiler attribute is available in gcc versions 4.3.0 and later.  */
#  define _GL_WARN_ON_USE(function, message) \
extern __typeof__ (function) function __attribute__ ((__warning__ (message)))
# elif __GNUC__ >= 3 && GNULIB_STRICT_CHECKING
/* Verify the existence of the function.  */
#  define _GL_WARN_ON_USE(function, message) \
extern __typeof__ (function) function
# else /* Unsupported.  */
#  define _GL_WARN_ON_USE(function, message) \
_GL_WARN_EXTERN_C int _gl_warn_on_use
# endif
#endif

/* _GL_WARN_ON_USE_CXX (function, rettype, parameters_and_attributes, "string")
   is like _GL_WARN_ON_USE (function, "string"), except that the function is
   declared with the given prototype, consisting of return type, parameters,
   and attributes.
   This variant is useful for overloaded functions in C++. _GL_WARN_ON_USE does
   not work in this case.  */
#ifndef _GL_WARN_ON_USE_CXX
# if 4 < __GNUC__ || (__GNUC__ == 4 && 3 <= __GNUC_MINOR__)
#  define _GL_WARN_ON_USE_CXX(function,rettype,parameters_and_attributes,msg) \
extern rettype function parameters_and_attributes \
     __attribute__ ((__warning__ (msg)))
# elif __GNUC__ >= 3 && GNULIB_STRICT_CHECKING
/* Verify the existence of the function.  */
#  define _GL_WARN_ON_USE_CXX(function,rettype,parameters_and_attributes,msg) \
extern rettype function parameters_and_attributes
# else /* Unsupported.  */
#  define _GL_WARN_ON_USE_CXX(function,rettype,parameters_and_attributes,msg) \
_GL_WARN_EXTERN_C int _gl_warn_on_use
# endif
#endif

/* _GL_WARN_EXTERN_C declaration;
   performs the declaration with C linkage.  */
#ifndef _GL_WARN_EXTERN_C
# if defined __cplusplus
#  define _GL_WARN_EXTERN_C extern "C"
# else
#  define _GL_WARN_EXTERN_C extern
# endif
#endif

/* Declarations for a platform that lacks <netdb.h>, or where it is
   incomplete.  */

#if 1

# if !1

#  ifdef __cplusplus
extern "C" {
#  endif

#  if !GNULIB_defined_struct_addrinfo
/* Structure to contain information about address of a service provider.  */
struct addrinfo
{
  int ai_flags;                 /* Input flags.  */
  int ai_family;                /* Protocol family for socket.  */
  int ai_socktype;              /* Socket type.  */
  int ai_protocol;              /* Protocol for socket.  */
  socklen_t ai_addrlen;         /* Length of socket address.  */
  struct sockaddr *ai_addr;     /* Socket address for socket.  */
  char *ai_canonname;           /* Canonical name for service location.  */
  struct addrinfo *ai_next;     /* Pointer to next in list.  */
};
#   define GNULIB_defined_struct_addrinfo 1
#  endif

#  ifdef __cplusplus
}
#  endif

# endif

/* Possible values for 'ai_flags' field in 'addrinfo' structure.  */
# ifndef AI_PASSIVE
#  define AI_PASSIVE    0x0001  /* Socket address is intended for 'bind'.  */
# endif
# ifndef AI_CANONNAME
#  define AI_CANONNAME  0x0002  /* Request for canonical name.  */
# endif
# ifndef AI_NUMERICSERV
#  define AI_NUMERICSERV        0x0400  /* Don't use name resolution.  */
# endif

# if 0
#  define AI_NUMERICHOST        0x0004  /* Don't use name resolution.  */
# endif

/* These symbolic constants are required to be present by POSIX, but
   our getaddrinfo replacement doesn't use them (yet).  Setting them
   to 0 on systems that doesn't have them avoids causing problems for
   system getaddrinfo implementations that would be confused by
   unknown values.  */
# ifndef AI_V4MAPPED
#  define AI_V4MAPPED    0 /* 0x0008: IPv4 mapped addresses are acceptable.  */
# endif
# ifndef AI_ALL
#  define AI_ALL         0 /* 0x0010: Return IPv4 mapped and IPv6 addresses. */
# endif
# ifndef AI_ADDRCONFIG
#  define AI_ADDRCONFIG  0 /* 0x0020: Use configuration of this host to choose
                                      returned address type.  */
# endif

/* Error values for 'getaddrinfo' function.  */
# ifndef EAI_BADFLAGS
#  define EAI_BADFLAGS    -1    /* Invalid value for 'ai_flags' field.  */
#  define EAI_NONAME      -2    /* NAME or SERVICE is unknown.  */
#  define EAI_AGAIN       -3    /* Temporary failure in name resolution.  */
#  define EAI_FAIL        -4    /* Non-recoverable failure in name res.  */
#  define EAI_NODATA      -5    /* No address associated with NAME.  */
#  define EAI_FAMILY      -6    /* 'ai_family' not supported.  */
#  define EAI_SOCKTYPE    -7    /* 'ai_socktype' not supported.  */
#  define EAI_SERVICE     -8    /* SERVICE not supported for 'ai_socktype'.  */
#  define EAI_MEMORY      -10   /* Memory allocation failure.  */
# endif

/* Since EAI_NODATA is deprecated by RFC3493, some systems (at least
   FreeBSD, which does define EAI_BADFLAGS) have removed the definition
   in favor of EAI_NONAME.  */
# if !defined EAI_NODATA && defined EAI_NONAME
#  define EAI_NODATA EAI_NONAME
# endif

# ifndef EAI_OVERFLOW
/* Not defined on mingw32 and Haiku. */
#  define EAI_OVERFLOW    -12   /* Argument buffer overflow.  */
# endif
# ifndef EAI_ADDRFAMILY
/* Not defined on mingw32. */
#  define EAI_ADDRFAMILY  -9    /* Address family for NAME not supported.  */
# endif
# ifndef EAI_SYSTEM
/* Not defined on mingw32. */
#  define EAI_SYSTEM      -11   /* System error returned in 'errno'.  */
# endif

# if 0
/* The commented out definitions below are not yet implemented in the
   GNULIB getaddrinfo() replacement, so are not yet needed.

   If they are restored, be sure to protect the definitions with #ifndef.  */
#  ifndef EAI_INPROGRESS
#   define EAI_INPROGRESS       -100    /* Processing request in progress.  */
#   define EAI_CANCELED         -101    /* Request canceled.  */
#   define EAI_NOTCANCELED      -102    /* Request not canceled.  */
#   define EAI_ALLDONE          -103    /* All requests done.  */
#   define EAI_INTR             -104    /* Interrupted by a signal.  */
#   define EAI_IDN_ENCODE       -105    /* IDN encoding failed.  */
#  endif
# endif

# if !1
/* Translate name of a service location and/or a service name to set of
   socket addresses.
   For more details, see the POSIX:2001 specification
   <http://www.opengroup.org/susv3xsh/getaddrinfo.html>.  */
_GL_FUNCDECL_SYS (getaddrinfo, int,
                  (const char *restrict nodename,
                   const char *restrict servname,
                   const struct addrinfo *restrict hints,
                   struct addrinfo **restrict res)
                  _GL_ARG_NONNULL ((4)));
# endif
_GL_CXXALIAS_SYS (getaddrinfo, int,
                  (const char *restrict nodename,
                   const char *restrict servname,
                   const struct addrinfo *restrict hints,
                   struct addrinfo **restrict res));
_GL_CXXALIASWARN (getaddrinfo);

# if !1
/* Free 'addrinfo' structure AI including associated storage.
   For more details, see the POSIX:2001 specification
   <http://www.opengroup.org/susv3xsh/getaddrinfo.html>.  */
_GL_FUNCDECL_SYS (freeaddrinfo, void, (struct addrinfo *ai)
                                      _GL_ARG_NONNULL ((1)));
# endif
_GL_CXXALIAS_SYS (freeaddrinfo, void, (struct addrinfo *ai));
_GL_CXXALIASWARN (freeaddrinfo);

# if 0
#  if !(defined __cplusplus && defined GNULIB_NAMESPACE)
#   undef gai_strerror
#   define gai_strerror rpl_gai_strerror
#  endif
_GL_FUNCDECL_RPL (gai_strerror, const char *, (int ecode));
_GL_CXXALIAS_RPL (gai_strerror, const char *, (int ecode));
# else
#  if !1
/* Convert error return from getaddrinfo() to a string.
   For more details, see the POSIX:2001 specification
   <http://www.opengroup.org/susv3xsh/gai_strerror.html>.  */
_GL_FUNCDECL_SYS (gai_strerror, const char *, (int ecode));
#  endif
_GL_CXXALIAS_SYS (gai_strerror, const char *, (int ecode));
# endif
_GL_CXXALIASWARN (gai_strerror);

# if !1
/* Convert socket address to printable node and service names.
   For more details, see the POSIX:2001 specification
   <http://www.opengroup.org/susv3xsh/getnameinfo.html>.  */
_GL_FUNCDECL_SYS (getnameinfo, int,
                  (const struct sockaddr *restrict sa, socklen_t salen,
                   char *restrict node, socklen_t nodelen,
                   char *restrict service, socklen_t servicelen,
                   int flags)
                  _GL_ARG_NONNULL ((1)));
# endif
/* Need to cast, because on glibc systems, the seventh parameter is
                        unsigned int flags.  */
_GL_CXXALIAS_SYS_CAST (getnameinfo, int,
                       (const struct sockaddr *restrict sa, socklen_t salen,
                        char *restrict node, socklen_t nodelen,
                        char *restrict service, socklen_t servicelen,
                        int flags));
_GL_CXXALIASWARN (getnameinfo);

/* Possible flags for getnameinfo.  */
# ifndef NI_NUMERICHOST
#  define NI_NUMERICHOST 1
# endif
# ifndef NI_NUMERICSERV
#  define NI_NUMERICSERV 2
# endif

#elif defined GNULIB_POSIXCHECK

# undef getaddrinfo
# if HAVE_RAW_DECL_GETADDRINFO
_GL_WARN_ON_USE (getaddrinfo, "getaddrinfo is unportable - "
                 "use gnulib module getaddrinfo for portability");
# endif

# undef freeaddrinfo
# if HAVE_RAW_DECL_FREEADDRINFO
_GL_WARN_ON_USE (freeaddrinfo, "freeaddrinfo is unportable - "
                 "use gnulib module getaddrinfo for portability");
# endif

# undef gai_strerror
# if HAVE_RAW_DECL_GAI_STRERROR
_GL_WARN_ON_USE (gai_strerror, "gai_strerror is unportable - "
                 "use gnulib module getaddrinfo for portability");
# endif

# undef getnameinfo
# if HAVE_RAW_DECL_GETNAMEINFO
_GL_WARN_ON_USE (getnameinfo, "getnameinfo is unportable - "
                 "use gnulib module getaddrinfo for portability");
# endif

#endif

#endif /* _GL_NETDB_H */
#endif /* _GL_NETDB_H */
