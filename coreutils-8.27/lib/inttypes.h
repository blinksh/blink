/* DO NOT EDIT! GENERATED AUTOMATICALLY! */
/* Copyright (C) 2006-2017 Free Software Foundation, Inc.
   Written by Paul Eggert, Bruno Haible, Derek Price.
   This file is part of gnulib.

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

/*
 * ISO C 99 <inttypes.h> for platforms that lack it.
 * <http://www.opengroup.org/susv3xbd/inttypes.h.html>
 */

#if __GNUC__ >= 3
#pragma GCC system_header
#endif


/* Include the original <inttypes.h> if it exists, and if this file
   has not been included yet or if this file includes gnulib stdint.h
   which in turn includes this file.
   The include_next requires a split double-inclusion guard.  */
#if ! defined INTTYPES_H || defined _GL_JUST_INCLUDE_SYSTEM_INTTYPES_H
# if 1

   /* Some pre-C++11 <stdint.h> implementations need this.  */
#  if defined __cplusplus && ! defined __STDC_FORMAT_MACROS
#   define __STDC_FORMAT_MACROS 1
#  endif

#  include_next <inttypes.h>
# endif
#endif

#if ! defined INTTYPES_H && ! defined _GL_JUST_INCLUDE_SYSTEM_INTTYPES_H
#define INTTYPES_H

/* Include <stdint.h> or the gnulib replacement.
   But avoid namespace pollution on glibc systems.  */
#ifndef __GLIBC__
# include <stdint.h>
#endif
/* Get CHAR_BIT.  */
#include <limits.h>
/* On mingw, __USE_MINGW_ANSI_STDIO only works if <stdio.h> is also included */
#if (defined _WIN32 || defined __WIN32__) && ! defined __CYGWIN__
# include <stdio.h>
#endif

#if !(INT_MIN == INT32_MIN && INT_MAX == INT32_MAX)
# error "This file assumes that 'int' has exactly 32 bits. Please report your platform and compiler to <bug-gnulib@gnu.org>."
#endif

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

/* 7.8.1 Macros for format specifiers */

#if defined _TNS_R_TARGET
   /* Tandem NonStop R series and compatible platforms released before
      July 2005 support %Ld but not %lld.  */
# define _LONG_LONG_FORMAT_PREFIX "L"
#else
# define _LONG_LONG_FORMAT_PREFIX "ll"
#endif

#if !defined PRId8 || 0
# undef PRId8
# ifdef INT8_MAX
#  define PRId8 "d"
# endif
#endif
#if !defined PRIi8 || 0
# undef PRIi8
# ifdef INT8_MAX
#  define PRIi8 "i"
# endif
#endif
#if !defined PRIo8 || 0
# undef PRIo8
# ifdef UINT8_MAX
#  define PRIo8 "o"
# endif
#endif
#if !defined PRIu8 || 0
# undef PRIu8
# ifdef UINT8_MAX
#  define PRIu8 "u"
# endif
#endif
#if !defined PRIx8 || 0
# undef PRIx8
# ifdef UINT8_MAX
#  define PRIx8 "x"
# endif
#endif
#if !defined PRIX8 || 0
# undef PRIX8
# ifdef UINT8_MAX
#  define PRIX8 "X"
# endif
#endif
#if !defined PRId16 || 0
# undef PRId16
# ifdef INT16_MAX
#  define PRId16 "d"
# endif
#endif
#if !defined PRIi16 || 0
# undef PRIi16
# ifdef INT16_MAX
#  define PRIi16 "i"
# endif
#endif
#if !defined PRIo16 || 0
# undef PRIo16
# ifdef UINT16_MAX
#  define PRIo16 "o"
# endif
#endif
#if !defined PRIu16 || 0
# undef PRIu16
# ifdef UINT16_MAX
#  define PRIu16 "u"
# endif
#endif
#if !defined PRIx16 || 0
# undef PRIx16
# ifdef UINT16_MAX
#  define PRIx16 "x"
# endif
#endif
#if !defined PRIX16 || 0
# undef PRIX16
# ifdef UINT16_MAX
#  define PRIX16 "X"
# endif
#endif
#if !defined PRId32 || 0
# undef PRId32
# ifdef INT32_MAX
#  define PRId32 "d"
# endif
#endif
#if !defined PRIi32 || 0
# undef PRIi32
# ifdef INT32_MAX
#  define PRIi32 "i"
# endif
#endif
#if !defined PRIo32 || 0
# undef PRIo32
# ifdef UINT32_MAX
#  define PRIo32 "o"
# endif
#endif
#if !defined PRIu32 || 0
# undef PRIu32
# ifdef UINT32_MAX
#  define PRIu32 "u"
# endif
#endif
#if !defined PRIx32 || 0
# undef PRIx32
# ifdef UINT32_MAX
#  define PRIx32 "x"
# endif
#endif
#if !defined PRIX32 || 0
# undef PRIX32
# ifdef UINT32_MAX
#  define PRIX32 "X"
# endif
#endif
#ifdef INT64_MAX
# if (0 ? defined _LP64 : 1)
#  define _PRI64_PREFIX "l"
# elif defined _MSC_VER || defined __MINGW32__
#  define _PRI64_PREFIX "I64"
# elif 1 && LONG_MAX >> 30 == 1
#  define _PRI64_PREFIX _LONG_LONG_FORMAT_PREFIX
# endif
# if !defined PRId64 || 0
#  undef PRId64
#  define PRId64 _PRI64_PREFIX "d"
# endif
# if !defined PRIi64 || 0
#  undef PRIi64
#  define PRIi64 _PRI64_PREFIX "i"
# endif
#endif
#ifdef UINT64_MAX
# if (0 ? defined _LP64 : 1)
#  define _PRIu64_PREFIX "l"
# elif defined _MSC_VER || defined __MINGW32__
#  define _PRIu64_PREFIX "I64"
# elif 1 && ULONG_MAX >> 31 == 1
#  define _PRIu64_PREFIX _LONG_LONG_FORMAT_PREFIX
# endif
# if !defined PRIo64 || 0
#  undef PRIo64
#  define PRIo64 _PRIu64_PREFIX "o"
# endif
# if !defined PRIu64 || 0
#  undef PRIu64
#  define PRIu64 _PRIu64_PREFIX "u"
# endif
# if !defined PRIx64 || 0
#  undef PRIx64
#  define PRIx64 _PRIu64_PREFIX "x"
# endif
# if !defined PRIX64 || 0
#  undef PRIX64
#  define PRIX64 _PRIu64_PREFIX "X"
# endif
#endif

#if !defined PRIdLEAST8 || 0
# undef PRIdLEAST8
# define PRIdLEAST8 "d"
#endif
#if !defined PRIiLEAST8 || 0
# undef PRIiLEAST8
# define PRIiLEAST8 "i"
#endif
#if !defined PRIoLEAST8 || 0
# undef PRIoLEAST8
# define PRIoLEAST8 "o"
#endif
#if !defined PRIuLEAST8 || 0
# undef PRIuLEAST8
# define PRIuLEAST8 "u"
#endif
#if !defined PRIxLEAST8 || 0
# undef PRIxLEAST8
# define PRIxLEAST8 "x"
#endif
#if !defined PRIXLEAST8 || 0
# undef PRIXLEAST8
# define PRIXLEAST8 "X"
#endif
#if !defined PRIdLEAST16 || 0
# undef PRIdLEAST16
# define PRIdLEAST16 "d"
#endif
#if !defined PRIiLEAST16 || 0
# undef PRIiLEAST16
# define PRIiLEAST16 "i"
#endif
#if !defined PRIoLEAST16 || 0
# undef PRIoLEAST16
# define PRIoLEAST16 "o"
#endif
#if !defined PRIuLEAST16 || 0
# undef PRIuLEAST16
# define PRIuLEAST16 "u"
#endif
#if !defined PRIxLEAST16 || 0
# undef PRIxLEAST16
# define PRIxLEAST16 "x"
#endif
#if !defined PRIXLEAST16 || 0
# undef PRIXLEAST16
# define PRIXLEAST16 "X"
#endif
#if !defined PRIdLEAST32 || 0
# undef PRIdLEAST32
# define PRIdLEAST32 "d"
#endif
#if !defined PRIiLEAST32 || 0
# undef PRIiLEAST32
# define PRIiLEAST32 "i"
#endif
#if !defined PRIoLEAST32 || 0
# undef PRIoLEAST32
# define PRIoLEAST32 "o"
#endif
#if !defined PRIuLEAST32 || 0
# undef PRIuLEAST32
# define PRIuLEAST32 "u"
#endif
#if !defined PRIxLEAST32 || 0
# undef PRIxLEAST32
# define PRIxLEAST32 "x"
#endif
#if !defined PRIXLEAST32 || 0
# undef PRIXLEAST32
# define PRIXLEAST32 "X"
#endif
#ifdef INT64_MAX
# if !defined PRIdLEAST64 || 0
#  undef PRIdLEAST64
#  define PRIdLEAST64 PRId64
# endif
# if !defined PRIiLEAST64 || 0
#  undef PRIiLEAST64
#  define PRIiLEAST64 PRIi64
# endif
#endif
#ifdef UINT64_MAX
# if !defined PRIoLEAST64 || 0
#  undef PRIoLEAST64
#  define PRIoLEAST64 PRIo64
# endif
# if !defined PRIuLEAST64 || 0
#  undef PRIuLEAST64
#  define PRIuLEAST64 PRIu64
# endif
# if !defined PRIxLEAST64 || 0
#  undef PRIxLEAST64
#  define PRIxLEAST64 PRIx64
# endif
# if !defined PRIXLEAST64 || 0
#  undef PRIXLEAST64
#  define PRIXLEAST64 PRIX64
# endif
#endif

#if !defined PRIdFAST8 || 0
# undef PRIdFAST8
# if INT_FAST8_MAX > INT32_MAX
#  define PRIdFAST8 PRId64
# else
#  define PRIdFAST8 "d"
# endif
#endif
#if !defined PRIiFAST8 || 0
# undef PRIiFAST8
# if INT_FAST8_MAX > INT32_MAX
#  define PRIiFAST8 PRIi64
# else
#  define PRIiFAST8 "i"
# endif
#endif
#if !defined PRIoFAST8 || 0
# undef PRIoFAST8
# if UINT_FAST8_MAX > UINT32_MAX
#  define PRIoFAST8 PRIo64
# else
#  define PRIoFAST8 "o"
# endif
#endif
#if !defined PRIuFAST8 || 0
# undef PRIuFAST8
# if UINT_FAST8_MAX > UINT32_MAX
#  define PRIuFAST8 PRIu64
# else
#  define PRIuFAST8 "u"
# endif
#endif
#if !defined PRIxFAST8 || 0
# undef PRIxFAST8
# if UINT_FAST8_MAX > UINT32_MAX
#  define PRIxFAST8 PRIx64
# else
#  define PRIxFAST8 "x"
# endif
#endif
#if !defined PRIXFAST8 || 0
# undef PRIXFAST8
# if UINT_FAST8_MAX > UINT32_MAX
#  define PRIXFAST8 PRIX64
# else
#  define PRIXFAST8 "X"
# endif
#endif
#if !defined PRIdFAST16 || 0
# undef PRIdFAST16
# if INT_FAST16_MAX > INT32_MAX
#  define PRIdFAST16 PRId64
# else
#  define PRIdFAST16 "d"
# endif
#endif
#if !defined PRIiFAST16 || 0
# undef PRIiFAST16
# if INT_FAST16_MAX > INT32_MAX
#  define PRIiFAST16 PRIi64
# else
#  define PRIiFAST16 "i"
# endif
#endif
#if !defined PRIoFAST16 || 0
# undef PRIoFAST16
# if UINT_FAST16_MAX > UINT32_MAX
#  define PRIoFAST16 PRIo64
# else
#  define PRIoFAST16 "o"
# endif
#endif
#if !defined PRIuFAST16 || 0
# undef PRIuFAST16
# if UINT_FAST16_MAX > UINT32_MAX
#  define PRIuFAST16 PRIu64
# else
#  define PRIuFAST16 "u"
# endif
#endif
#if !defined PRIxFAST16 || 0
# undef PRIxFAST16
# if UINT_FAST16_MAX > UINT32_MAX
#  define PRIxFAST16 PRIx64
# else
#  define PRIxFAST16 "x"
# endif
#endif
#if !defined PRIXFAST16 || 0
# undef PRIXFAST16
# if UINT_FAST16_MAX > UINT32_MAX
#  define PRIXFAST16 PRIX64
# else
#  define PRIXFAST16 "X"
# endif
#endif
#if !defined PRIdFAST32 || 0
# undef PRIdFAST32
# if INT_FAST32_MAX > INT32_MAX
#  define PRIdFAST32 PRId64
# else
#  define PRIdFAST32 "d"
# endif
#endif
#if !defined PRIiFAST32 || 0
# undef PRIiFAST32
# if INT_FAST32_MAX > INT32_MAX
#  define PRIiFAST32 PRIi64
# else
#  define PRIiFAST32 "i"
# endif
#endif
#if !defined PRIoFAST32 || 0
# undef PRIoFAST32
# if UINT_FAST32_MAX > UINT32_MAX
#  define PRIoFAST32 PRIo64
# else
#  define PRIoFAST32 "o"
# endif
#endif
#if !defined PRIuFAST32 || 0
# undef PRIuFAST32
# if UINT_FAST32_MAX > UINT32_MAX
#  define PRIuFAST32 PRIu64
# else
#  define PRIuFAST32 "u"
# endif
#endif
#if !defined PRIxFAST32 || 0
# undef PRIxFAST32
# if UINT_FAST32_MAX > UINT32_MAX
#  define PRIxFAST32 PRIx64
# else
#  define PRIxFAST32 "x"
# endif
#endif
#if !defined PRIXFAST32 || 0
# undef PRIXFAST32
# if UINT_FAST32_MAX > UINT32_MAX
#  define PRIXFAST32 PRIX64
# else
#  define PRIXFAST32 "X"
# endif
#endif
#ifdef INT64_MAX
# if !defined PRIdFAST64 || 0
#  undef PRIdFAST64
#  define PRIdFAST64 PRId64
# endif
# if !defined PRIiFAST64 || 0
#  undef PRIiFAST64
#  define PRIiFAST64 PRIi64
# endif
#endif
#ifdef UINT64_MAX
# if !defined PRIoFAST64 || 0
#  undef PRIoFAST64
#  define PRIoFAST64 PRIo64
# endif
# if !defined PRIuFAST64 || 0
#  undef PRIuFAST64
#  define PRIuFAST64 PRIu64
# endif
# if !defined PRIxFAST64 || 0
#  undef PRIxFAST64
#  define PRIxFAST64 PRIx64
# endif
# if !defined PRIXFAST64 || 0
#  undef PRIXFAST64
#  define PRIXFAST64 PRIX64
# endif
#endif

#if !defined PRIdMAX || 0
# undef PRIdMAX
# if 1
#  define PRIdMAX PRId64
# else
#  define PRIdMAX "ld"
# endif
#endif
#if !defined PRIiMAX || 0
# undef PRIiMAX
# if 1
#  define PRIiMAX PRIi64
# else
#  define PRIiMAX "li"
# endif
#endif
#if !defined PRIoMAX || 0
# undef PRIoMAX
# if 1
#  define PRIoMAX PRIo64
# else
#  define PRIoMAX "lo"
# endif
#endif
#if !defined PRIuMAX || 0
# undef PRIuMAX
# if 1
#  define PRIuMAX PRIu64
# else
#  define PRIuMAX "lu"
# endif
#endif
#if !defined PRIxMAX || 0
# undef PRIxMAX
# if 1
#  define PRIxMAX PRIx64
# else
#  define PRIxMAX "lx"
# endif
#endif
#if !defined PRIXMAX || 0
# undef PRIXMAX
# if 1
#  define PRIXMAX PRIX64
# else
#  define PRIXMAX "lX"
# endif
#endif

#if !defined PRIdPTR || 0
# undef PRIdPTR
# ifdef INTPTR_MAX
#  define PRIdPTR "l" "d"
# endif
#endif
#if !defined PRIiPTR || 0
# undef PRIiPTR
# ifdef INTPTR_MAX
#  define PRIiPTR "l" "i"
# endif
#endif
#if !defined PRIoPTR || 0
# undef PRIoPTR
# ifdef UINTPTR_MAX
#  define PRIoPTR "l" "o"
# endif
#endif
#if !defined PRIuPTR || 0
# undef PRIuPTR
# ifdef UINTPTR_MAX
#  define PRIuPTR "l" "u"
# endif
#endif
#if !defined PRIxPTR || 0
# undef PRIxPTR
# ifdef UINTPTR_MAX
#  define PRIxPTR "l" "x"
# endif
#endif
#if !defined PRIXPTR || 0
# undef PRIXPTR
# ifdef UINTPTR_MAX
#  define PRIXPTR "l" "X"
# endif
#endif

#if !defined SCNd8 || 0
# undef SCNd8
# ifdef INT8_MAX
#  define SCNd8 "hhd"
# endif
#endif
#if !defined SCNi8 || 0
# undef SCNi8
# ifdef INT8_MAX
#  define SCNi8 "hhi"
# endif
#endif
#if !defined SCNo8 || 0
# undef SCNo8
# ifdef UINT8_MAX
#  define SCNo8 "hho"
# endif
#endif
#if !defined SCNu8 || 0
# undef SCNu8
# ifdef UINT8_MAX
#  define SCNu8 "hhu"
# endif
#endif
#if !defined SCNx8 || 0
# undef SCNx8
# ifdef UINT8_MAX
#  define SCNx8 "hhx"
# endif
#endif
#if !defined SCNd16 || 0
# undef SCNd16
# ifdef INT16_MAX
#  define SCNd16 "hd"
# endif
#endif
#if !defined SCNi16 || 0
# undef SCNi16
# ifdef INT16_MAX
#  define SCNi16 "hi"
# endif
#endif
#if !defined SCNo16 || 0
# undef SCNo16
# ifdef UINT16_MAX
#  define SCNo16 "ho"
# endif
#endif
#if !defined SCNu16 || 0
# undef SCNu16
# ifdef UINT16_MAX
#  define SCNu16 "hu"
# endif
#endif
#if !defined SCNx16 || 0
# undef SCNx16
# ifdef UINT16_MAX
#  define SCNx16 "hx"
# endif
#endif
#if !defined SCNd32 || 0
# undef SCNd32
# ifdef INT32_MAX
#  define SCNd32 "d"
# endif
#endif
#if !defined SCNi32 || 0
# undef SCNi32
# ifdef INT32_MAX
#  define SCNi32 "i"
# endif
#endif
#if !defined SCNo32 || 0
# undef SCNo32
# ifdef UINT32_MAX
#  define SCNo32 "o"
# endif
#endif
#if !defined SCNu32 || 0
# undef SCNu32
# ifdef UINT32_MAX
#  define SCNu32 "u"
# endif
#endif
#if !defined SCNx32 || 0
# undef SCNx32
# ifdef UINT32_MAX
#  define SCNx32 "x"
# endif
#endif
#ifdef INT64_MAX
# if (0 ? defined _LP64 : 1)
#  define _SCN64_PREFIX "l"
# elif defined _MSC_VER || defined __MINGW32__
#  define _SCN64_PREFIX "I64"
# elif 1 && LONG_MAX >> 30 == 1
#  define _SCN64_PREFIX _LONG_LONG_FORMAT_PREFIX
# endif
# if !defined SCNd64 || 0
#  undef SCNd64
#  define SCNd64 _SCN64_PREFIX "d"
# endif
# if !defined SCNi64 || 0
#  undef SCNi64
#  define SCNi64 _SCN64_PREFIX "i"
# endif
#endif
#ifdef UINT64_MAX
# if (0 ? defined _LP64 : 1)
#  define _SCNu64_PREFIX "l"
# elif defined _MSC_VER || defined __MINGW32__
#  define _SCNu64_PREFIX "I64"
# elif 1 && ULONG_MAX >> 31 == 1
#  define _SCNu64_PREFIX _LONG_LONG_FORMAT_PREFIX
# endif
# if !defined SCNo64 || 0
#  undef SCNo64
#  define SCNo64 _SCNu64_PREFIX "o"
# endif
# if !defined SCNu64 || 0
#  undef SCNu64
#  define SCNu64 _SCNu64_PREFIX "u"
# endif
# if !defined SCNx64 || 0
#  undef SCNx64
#  define SCNx64 _SCNu64_PREFIX "x"
# endif
#endif

#if !defined SCNdLEAST8 || 0
# undef SCNdLEAST8
# define SCNdLEAST8 "hhd"
#endif
#if !defined SCNiLEAST8 || 0
# undef SCNiLEAST8
# define SCNiLEAST8 "hhi"
#endif
#if !defined SCNoLEAST8 || 0
# undef SCNoLEAST8
# define SCNoLEAST8 "hho"
#endif
#if !defined SCNuLEAST8 || 0
# undef SCNuLEAST8
# define SCNuLEAST8 "hhu"
#endif
#if !defined SCNxLEAST8 || 0
# undef SCNxLEAST8
# define SCNxLEAST8 "hhx"
#endif
#if !defined SCNdLEAST16 || 0
# undef SCNdLEAST16
# define SCNdLEAST16 "hd"
#endif
#if !defined SCNiLEAST16 || 0
# undef SCNiLEAST16
# define SCNiLEAST16 "hi"
#endif
#if !defined SCNoLEAST16 || 0
# undef SCNoLEAST16
# define SCNoLEAST16 "ho"
#endif
#if !defined SCNuLEAST16 || 0
# undef SCNuLEAST16
# define SCNuLEAST16 "hu"
#endif
#if !defined SCNxLEAST16 || 0
# undef SCNxLEAST16
# define SCNxLEAST16 "hx"
#endif
#if !defined SCNdLEAST32 || 0
# undef SCNdLEAST32
# define SCNdLEAST32 "d"
#endif
#if !defined SCNiLEAST32 || 0
# undef SCNiLEAST32
# define SCNiLEAST32 "i"
#endif
#if !defined SCNoLEAST32 || 0
# undef SCNoLEAST32
# define SCNoLEAST32 "o"
#endif
#if !defined SCNuLEAST32 || 0
# undef SCNuLEAST32
# define SCNuLEAST32 "u"
#endif
#if !defined SCNxLEAST32 || 0
# undef SCNxLEAST32
# define SCNxLEAST32 "x"
#endif
#ifdef INT64_MAX
# if !defined SCNdLEAST64 || 0
#  undef SCNdLEAST64
#  define SCNdLEAST64 SCNd64
# endif
# if !defined SCNiLEAST64 || 0
#  undef SCNiLEAST64
#  define SCNiLEAST64 SCNi64
# endif
#endif
#ifdef UINT64_MAX
# if !defined SCNoLEAST64 || 0
#  undef SCNoLEAST64
#  define SCNoLEAST64 SCNo64
# endif
# if !defined SCNuLEAST64 || 0
#  undef SCNuLEAST64
#  define SCNuLEAST64 SCNu64
# endif
# if !defined SCNxLEAST64 || 0
#  undef SCNxLEAST64
#  define SCNxLEAST64 SCNx64
# endif
#endif

#if !defined SCNdFAST8 || 0
# undef SCNdFAST8
# if INT_FAST8_MAX > INT32_MAX
#  define SCNdFAST8 SCNd64
# elif INT_FAST8_MAX == 0x7fff
#  define SCNdFAST8 "hd"
# elif INT_FAST8_MAX == 0x7f
#  define SCNdFAST8 "hhd"
# else
#  define SCNdFAST8 "d"
# endif
#endif
#if !defined SCNiFAST8 || 0
# undef SCNiFAST8
# if INT_FAST8_MAX > INT32_MAX
#  define SCNiFAST8 SCNi64
# elif INT_FAST8_MAX == 0x7fff
#  define SCNiFAST8 "hi"
# elif INT_FAST8_MAX == 0x7f
#  define SCNiFAST8 "hhi"
# else
#  define SCNiFAST8 "i"
# endif
#endif
#if !defined SCNoFAST8 || 0
# undef SCNoFAST8
# if UINT_FAST8_MAX > UINT32_MAX
#  define SCNoFAST8 SCNo64
# elif UINT_FAST8_MAX == 0xffff
#  define SCNoFAST8 "ho"
# elif UINT_FAST8_MAX == 0xff
#  define SCNoFAST8 "hho"
# else
#  define SCNoFAST8 "o"
# endif
#endif
#if !defined SCNuFAST8 || 0
# undef SCNuFAST8
# if UINT_FAST8_MAX > UINT32_MAX
#  define SCNuFAST8 SCNu64
# elif UINT_FAST8_MAX == 0xffff
#  define SCNuFAST8 "hu"
# elif UINT_FAST8_MAX == 0xff
#  define SCNuFAST8 "hhu"
# else
#  define SCNuFAST8 "u"
# endif
#endif
#if !defined SCNxFAST8 || 0
# undef SCNxFAST8
# if UINT_FAST8_MAX > UINT32_MAX
#  define SCNxFAST8 SCNx64
# elif UINT_FAST8_MAX == 0xffff
#  define SCNxFAST8 "hx"
# elif UINT_FAST8_MAX == 0xff
#  define SCNxFAST8 "hhx"
# else
#  define SCNxFAST8 "x"
# endif
#endif
#if !defined SCNdFAST16 || 0
# undef SCNdFAST16
# if INT_FAST16_MAX > INT32_MAX
#  define SCNdFAST16 SCNd64
# elif INT_FAST16_MAX == 0x7fff
#  define SCNdFAST16 "hd"
# else
#  define SCNdFAST16 "d"
# endif
#endif
#if !defined SCNiFAST16 || 0
# undef SCNiFAST16
# if INT_FAST16_MAX > INT32_MAX
#  define SCNiFAST16 SCNi64
# elif INT_FAST16_MAX == 0x7fff
#  define SCNiFAST16 "hi"
# else
#  define SCNiFAST16 "i"
# endif
#endif
#if !defined SCNoFAST16 || 0
# undef SCNoFAST16
# if UINT_FAST16_MAX > UINT32_MAX
#  define SCNoFAST16 SCNo64
# elif UINT_FAST16_MAX == 0xffff
#  define SCNoFAST16 "ho"
# else
#  define SCNoFAST16 "o"
# endif
#endif
#if !defined SCNuFAST16 || 0
# undef SCNuFAST16
# if UINT_FAST16_MAX > UINT32_MAX
#  define SCNuFAST16 SCNu64
# elif UINT_FAST16_MAX == 0xffff
#  define SCNuFAST16 "hu"
# else
#  define SCNuFAST16 "u"
# endif
#endif
#if !defined SCNxFAST16 || 0
# undef SCNxFAST16
# if UINT_FAST16_MAX > UINT32_MAX
#  define SCNxFAST16 SCNx64
# elif UINT_FAST16_MAX == 0xffff
#  define SCNxFAST16 "hx"
# else
#  define SCNxFAST16 "x"
# endif
#endif
#if !defined SCNdFAST32 || 0
# undef SCNdFAST32
# if INT_FAST32_MAX > INT32_MAX
#  define SCNdFAST32 SCNd64
# else
#  define SCNdFAST32 "d"
# endif
#endif
#if !defined SCNiFAST32 || 0
# undef SCNiFAST32
# if INT_FAST32_MAX > INT32_MAX
#  define SCNiFAST32 SCNi64
# else
#  define SCNiFAST32 "i"
# endif
#endif
#if !defined SCNoFAST32 || 0
# undef SCNoFAST32
# if UINT_FAST32_MAX > UINT32_MAX
#  define SCNoFAST32 SCNo64
# else
#  define SCNoFAST32 "o"
# endif
#endif
#if !defined SCNuFAST32 || 0
# undef SCNuFAST32
# if UINT_FAST32_MAX > UINT32_MAX
#  define SCNuFAST32 SCNu64
# else
#  define SCNuFAST32 "u"
# endif
#endif
#if !defined SCNxFAST32 || 0
# undef SCNxFAST32
# if UINT_FAST32_MAX > UINT32_MAX
#  define SCNxFAST32 SCNx64
# else
#  define SCNxFAST32 "x"
# endif
#endif
#ifdef INT64_MAX
# if !defined SCNdFAST64 || 0
#  undef SCNdFAST64
#  define SCNdFAST64 SCNd64
# endif
# if !defined SCNiFAST64 || 0
#  undef SCNiFAST64
#  define SCNiFAST64 SCNi64
# endif
#endif
#ifdef UINT64_MAX
# if !defined SCNoFAST64 || 0
#  undef SCNoFAST64
#  define SCNoFAST64 SCNo64
# endif
# if !defined SCNuFAST64 || 0
#  undef SCNuFAST64
#  define SCNuFAST64 SCNu64
# endif
# if !defined SCNxFAST64 || 0
#  undef SCNxFAST64
#  define SCNxFAST64 SCNx64
# endif
#endif

#if !defined SCNdMAX || 0
# undef SCNdMAX
# if 1
#  define SCNdMAX SCNd64
# else
#  define SCNdMAX "ld"
# endif
#endif
#if !defined SCNiMAX || 0
# undef SCNiMAX
# if 1
#  define SCNiMAX SCNi64
# else
#  define SCNiMAX "li"
# endif
#endif
#if !defined SCNoMAX || 0
# undef SCNoMAX
# if 1
#  define SCNoMAX SCNo64
# else
#  define SCNoMAX "lo"
# endif
#endif
#if !defined SCNuMAX || 0
# undef SCNuMAX
# if 1
#  define SCNuMAX SCNu64
# else
#  define SCNuMAX "lu"
# endif
#endif
#if !defined SCNxMAX || 0
# undef SCNxMAX
# if 1
#  define SCNxMAX SCNx64
# else
#  define SCNxMAX "lx"
# endif
#endif

#if !defined SCNdPTR || 0
# undef SCNdPTR
# ifdef INTPTR_MAX
#  define SCNdPTR "l" "d"
# endif
#endif
#if !defined SCNiPTR || 0
# undef SCNiPTR
# ifdef INTPTR_MAX
#  define SCNiPTR "l" "i"
# endif
#endif
#if !defined SCNoPTR || 0
# undef SCNoPTR
# ifdef UINTPTR_MAX
#  define SCNoPTR "l" "o"
# endif
#endif
#if !defined SCNuPTR || 0
# undef SCNuPTR
# ifdef UINTPTR_MAX
#  define SCNuPTR "l" "u"
# endif
#endif
#if !defined SCNxPTR || 0
# undef SCNxPTR
# ifdef UINTPTR_MAX
#  define SCNxPTR "l" "x"
# endif
#endif

/* 7.8.2 Functions for greatest-width integer types */

#ifdef __cplusplus
extern "C" {
#endif

#if 0
# if !1
extern intmax_t imaxabs (intmax_t);
# endif
#elif defined GNULIB_POSIXCHECK
# undef imaxabs
# if HAVE_RAW_DECL_IMAXABS
_GL_WARN_ON_USE (imaxabs, "imaxabs is unportable - "
                 "use gnulib module imaxabs for portability");
# endif
#endif

#if 0
# if !1
#  if !GNULIB_defined_imaxdiv_t
typedef struct { intmax_t quot; intmax_t rem; } imaxdiv_t;
#   define GNULIB_defined_imaxdiv_t 1
#  endif
extern imaxdiv_t imaxdiv (intmax_t, intmax_t);
# endif
#elif defined GNULIB_POSIXCHECK
# undef imaxdiv
# if HAVE_RAW_DECL_IMAXDIV
_GL_WARN_ON_USE (imaxdiv, "imaxdiv is unportable - "
                 "use gnulib module imaxdiv for portability");
# endif
#endif

#if 1
# if 0
#  if !(defined __cplusplus && defined GNULIB_NAMESPACE)
#   undef strtoimax
#   define strtoimax rpl_strtoimax
#  endif
_GL_FUNCDECL_RPL (strtoimax, intmax_t,
                  (const char *, char **, int) _GL_ARG_NONNULL ((1)));
_GL_CXXALIAS_RPL (strtoimax, intmax_t, (const char *, char **, int));
# else
#  if !1
#   undef strtoimax
_GL_FUNCDECL_SYS (strtoimax, intmax_t,
                  (const char *, char **, int) _GL_ARG_NONNULL ((1)));
#  endif
_GL_CXXALIAS_SYS (strtoimax, intmax_t, (const char *, char **, int));
# endif
_GL_CXXALIASWARN (strtoimax);
#elif defined GNULIB_POSIXCHECK
# undef strtoimax
# if HAVE_RAW_DECL_STRTOIMAX
_GL_WARN_ON_USE (strtoimax, "strtoimax is unportable - "
                 "use gnulib module strtoimax for portability");
# endif
#endif

#if 1
# if 0
#  if !(defined __cplusplus && defined GNULIB_NAMESPACE)
#   undef strtoumax
#   define strtoumax rpl_strtoumax
#  endif
_GL_FUNCDECL_RPL (strtoumax, uintmax_t,
                  (const char *, char **, int) _GL_ARG_NONNULL ((1)));
_GL_CXXALIAS_RPL (strtoumax, uintmax_t, (const char *, char **, int));
# else
#  if !1
#   undef strtoumax
_GL_FUNCDECL_SYS (strtoumax, uintmax_t,
                  (const char *, char **, int) _GL_ARG_NONNULL ((1)));
#  endif
_GL_CXXALIAS_SYS (strtoumax, uintmax_t, (const char *, char **, int));
# endif
_GL_CXXALIASWARN (strtoumax);
#elif defined GNULIB_POSIXCHECK
# undef strtoumax
# if HAVE_RAW_DECL_STRTOUMAX
_GL_WARN_ON_USE (strtoumax, "strtoumax is unportable - "
                 "use gnulib module strtoumax for portability");
# endif
#endif

/* Don't bother defining or declaring wcstoimax and wcstoumax, since
   wide-character functions like this are hardly ever useful.  */

#ifdef __cplusplus
}
#endif

#endif /* !defined INTTYPES_H && !defined _GL_JUST_INCLUDE_SYSTEM_INTTYPES_H */
