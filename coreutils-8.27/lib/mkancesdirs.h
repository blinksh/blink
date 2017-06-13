#include <stddef.h>
struct savewd;
ptrdiff_t mkancesdirs (char *, struct savewd *,
                       int (*) (char const *, char const *, void *), void *);
