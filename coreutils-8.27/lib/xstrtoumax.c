#define __strtol strtoumax
#define __strtol_t uintmax_t
#define __xstrtol xstrtoumax
#define STRTOL_T_MINIMUM 0
#define STRTOL_T_MAXIMUM UINTMAX_MAX
#include "xstrtol.c"
