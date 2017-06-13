/* a simple ring buffer
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

/* written by Jim Meyering */

#include "config.h"
#include "i-ring.h"

#include <stdlib.h>

void
i_ring_init (I_ring *ir, int default_val)
{
  int i;
  ir->ir_empty = true;
  ir->ir_front = 0;
  ir->ir_back = 0;
  for (i = 0; i < I_RING_SIZE; i++)
    ir->ir_data[i] = default_val;
  ir->ir_default_val = default_val;
}

bool
i_ring_empty (I_ring const *ir)
{
  return ir->ir_empty;
}

int
i_ring_push (I_ring *ir, int val)
{
  unsigned int dest_idx = (ir->ir_front + !ir->ir_empty) % I_RING_SIZE;
  int old_val = ir->ir_data[dest_idx];
  ir->ir_data[dest_idx] = val;
  ir->ir_front = dest_idx;
  if (dest_idx == ir->ir_back)
    ir->ir_back = (ir->ir_back + !ir->ir_empty) % I_RING_SIZE;
  ir->ir_empty = false;
  return old_val;
}

int
i_ring_pop (I_ring *ir)
{
  int top_val;
  if (i_ring_empty (ir))
    abort ();
  top_val = ir->ir_data[ir->ir_front];
  ir->ir_data[ir->ir_front] = ir->ir_default_val;
  if (ir->ir_front == ir->ir_back)
    ir->ir_empty = true;
  else
    ir->ir_front = ((ir->ir_front + I_RING_SIZE - 1) % I_RING_SIZE);
  return top_val;
}
