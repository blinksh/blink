#include <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonDigestSPI.h>

char *Digest_End(CCDigestRef, char *);

char *Digest_Data(CCDigestAlg, const void *, size_t, char *);

char *Digest_File(CCDigestAlg, const char *, char *);
