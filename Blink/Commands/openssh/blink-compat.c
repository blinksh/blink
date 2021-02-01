#include <errno.h>
#include <stdio.h>
#include <ctype.h>
#include <limits.h>


#include "blink-compat.h"


void
freezero(void *ptr, size_t sz)
{
  if (ptr == NULL)
    return;
  explicit_bzero(ptr, sz);
  free(ptr);
}

void
lowercase(char *s)
{
  for (; *s; s++)
    *s = tolower((u_char)*s);
}

long
convtime(const char *s)
{
  long total, secs, multiplier = 1;
  const char *p;
  char *endp;
  
  errno = 0;
  total = 0;
  p = s;
  
  if (p == NULL || *p == '\0')
    return -1;
  
  while (*p) {
    secs = strtol(p, &endp, 10);
    if (p == endp ||
        (errno == ERANGE && (secs == LONG_MIN || secs == LONG_MAX)) ||
        secs < 0)
      return -1;
    
    switch (*endp++) {
      case '\0':
        endp--;
        break;
      case 's':
      case 'S':
        break;
      case 'm':
      case 'M':
        multiplier = MINUTES;
        break;
      case 'h':
      case 'H':
        multiplier = HOURS;
        break;
      case 'd':
      case 'D':
        multiplier = DAYS;
        break;
      case 'w':
      case 'W':
        multiplier = WEEKS;
        break;
      default:
        return -1;
    }
    if (secs >= LONG_MAX / multiplier)
      return -1;
    secs *= multiplier;
    if  (total >= LONG_MAX - secs)
      return -1;
    total += secs;
    if (total < 0)
      return -1;
    p = endp;
  }
  
  return total;
}
