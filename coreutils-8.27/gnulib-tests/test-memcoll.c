/*
 * Copyright (C) 2008-2017 Free Software Foundation, Inc.
 * Written by Simon Josefsson and Bruno Haible
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

#include <config.h>

#include "memcoll.h"

#include <string.h>

#include "macros.h"

int
main (void)
{
  /* Test equal / not equal distinction.  */
  ASSERT (memcoll0 ("", 1, "", 1) == 0);
  ASSERT (memcoll0 ("fo", 3, "fo", 3) == 0);
  ASSERT (memcoll0 ("foo", 4, "foo", 4) == 0);
  ASSERT (memcoll0 ("foo\0", 5, "foob", 5) != 0);
  ASSERT (memcoll0 ("f", 2, "b", 2) != 0);
  ASSERT (memcoll0 ("foo", 4, "bar", 4) != 0);

  /* Test less / equal / greater distinction.  */
  ASSERT (memcoll0 ("foo\0", 5, "moo\0", 5) < 0);
  ASSERT (memcoll0 ("moo\0", 5, "foo\0", 5) > 0);
  ASSERT (memcoll0 ("oom", 4, "oop", 4) < 0);
  ASSERT (memcoll0 ("oop", 4, "oom", 4) > 0);
  ASSERT (memcoll0 ("foo\0", 5, "foob", 5) < 0);
  ASSERT (memcoll0 ("foob", 5, "foo\0", 5) > 0);

  /* Test embedded NULs.  */
  ASSERT (memcoll0 ("1\0", 3, "2\0", 3) < 0);
  ASSERT (memcoll0 ("2\0", 3, "1\0", 3) > 0);
  ASSERT (memcoll0 ("x\0""1", 4, "x\0""2", 4) < 0);
  ASSERT (memcoll0 ("x\0""2", 4, "x\0""1", 4) > 0);

  return 0;
}
