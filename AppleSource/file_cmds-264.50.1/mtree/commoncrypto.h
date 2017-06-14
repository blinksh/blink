#include <CommonCrypto/CommonDigestSPI.h>

#define kNone "none"

extern const int kSHA256NullTerminatedBuffLen;

#define MD5File(f, b)        Digest_File(kCCDigestMD5, f, b)
#define SHA1_File(f, b)      Digest_File(kCCDigestSHA1, f, b)
#define RIPEMD160_File(f, b) Digest_File(kCCDigestRMD160, f, b)
#define SHA256_File(f, b)    Digest_File(kCCDigestSHA256, f, b)

char *Digest_File(CCDigestAlg algorithm, const char *filename, char *buf);

char *SHA256_Path_XATTRs(char *path, char *buf);
char *SHA256_Path_ACL(char *path, char *buf);