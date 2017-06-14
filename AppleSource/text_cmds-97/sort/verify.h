/* Compile-time assert-like macros.

   Copyright (C) 2005 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software Foundation,
   Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.  */

/* Written by Paul Eggert and Jim Meyering.  */

#ifndef VERIFY_H
# define VERIFY_H 1

/* Each of these macros verifies that its argument R is a nonzero
   constant expression.  To be portable, R's type must be integer (or
   boolean).  Unlike assert, there is no run-time overhead.  */

/* A type that is valid if and only if R is a nonzero constant expression.
   The symbols verify_type__ and verify_error_if_negative_size__ are
   private to this header file.  */

# define verify_type__(R) \
    struct { unsigned int verify_error_if_negative_size__ : (R) ? 1 : -1; }

/* Verify requirement R at compile-time, as a declaration.  */

# define verify(R) \
    extern int (* verify_function__ (void)) [sizeof (verify_type__ (R))]

/* Verify requirement R at compile-time, as an expression.
   This macro can be used in some contexts where verify cannot, and vice versa.
   Return void.  */

# define verify_expr(R) ((void) ((verify_type__ (R) *) 0))

#endif
