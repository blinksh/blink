#define __strtol strtoimax
#define __strtol_t intmax_t
#define __xstrtol xstrtoimax
#define STRTOL_T_MINIMUM INTMAX_MIN
#define STRTOL_T_MAXIMUM INTMAX_MAX
#include "xstrtol.c"
