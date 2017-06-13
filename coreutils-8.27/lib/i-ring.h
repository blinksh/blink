/* definitions for a simple ring buffer
   Copyright (C) 2006, 2009-2017 Free Software Foundation, Inc.

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

#include <stdbool.h>
#include "verify.h"

enum { I_RING_SIZE = 4 };
verify (1 <= I_RING_SIZE);

/* When ir_empty is true, the ring is empty.
   Otherwise, ir_data[B..F] are defined, where B..F is the contiguous
   range of indices, modulo I_RING_SIZE, from back to front, inclusive.
   Undefined elements of ir_data are always set to ir_default_val.
   Popping from an empty ring aborts.
   Pushing onto a full ring returns the displaced value.
   An empty ring has F==B and ir_empty == true.
   A ring with one entry still has F==B, but now ir_empty == false.  */
struct I_ring
{
  int ir_data[I_RING_SIZE];
  int ir_default_val;
  unsigned int ir_front;
  unsigned int ir_back;
  bool ir_empty;
};
typedef struct I_ring I_ring;

void i_ring_init (I_ring *ir, int ir_default_val);
int i_ring_push (I_ring *ir, int val);
int i_ring_pop (I_ring *ir);
bool i_ring_empty (I_ring const *ir) _GL_ATTRIBUTE_PURE;
