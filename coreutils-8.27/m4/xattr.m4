# xattr.m4 - check for Extended Attributes (Linux)
# serial 3

# Copyright (C) 2003-2017 Free Software Foundation, Inc.
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

# Originally written by Andreas Gruenbacher.

AC_DEFUN([gl_FUNC_XATTR],
[
  AC_ARG_ENABLE([xattr],
        AC_HELP_STRING([--disable-xattr],
                       [do not support extended attributes]),
        [use_xattr=$enableval], [use_xattr=yes])

  LIB_XATTR=
  AC_SUBST([LIB_XATTR])

  if test "$use_xattr" = "yes"; then
    AC_CHECK_HEADERS([attr/error_context.h attr/libattr.h])
    use_xattr=no
    if test $ac_cv_header_attr_libattr_h = yes \
        && test $ac_cv_header_attr_error_context_h = yes; then
      xattr_saved_LIBS=$LIBS
      AC_SEARCH_LIBS([attr_copy_file], [attr],
                     [test "$ac_cv_search_attr_copy_file" = "none required" ||
                        LIB_XATTR=$ac_cv_search_attr_copy_file])
      AC_CHECK_FUNCS([attr_copy_file])
      LIBS=$xattr_saved_LIBS
      if test $ac_cv_func_attr_copy_file = yes; then
        use_xattr=yes
      fi
    fi
    if test $use_xattr = no; then
      AC_MSG_WARN([libattr development library was not found or not usable.])
      AC_MSG_WARN([AC_PACKAGE_NAME will be built without xattr support.])
    fi
  fi
  AC_DEFINE_UNQUOTED([USE_XATTR], [`test $use_xattr != yes; echo $?`],
                     [Define if you want extended attribute support.])
])
