////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016 Blink Mobile Shell Project
//
// This file is part of Blink.
//
// Blink is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Blink is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Blink. If not, see <http://www.gnu.org/licenses/>.
//
// In addition, Blink is also subject to certain additional terms under
// GNU GPL version 3 section 7.
//
// You should have received a copy of these additional terms immediately
// following the terms and conditions of the GNU General Public License
// which accompanied the Blink Source Code. If not, see
// <http://www.github.com/blinksh/blink>.
//
////////////////////////////////////////////////////////////////////////////////

#include <openssl/bio.h>
#include <openssl/bn.h>
#include <openssl/err.h>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/rsa.h>

#import "BKPubKey.h"
#import "UICKeyChainStore/UICKeyChainStore.h"


// typedef enum IDCardType : NSUInteger {
//   RSA2048,
//   RSA4096
// }IDCardType;
static unsigned char pSshHeader[11] = {0x00, 0x00, 0x00, 0x07, 0x73, 0x73, 0x68, 0x2D, 0x72, 0x73, 0x61};
NSMutableArray *Identities;

static NSURL *DocumentsDirectory = nil;
static NSURL *KeysURL = nil;
static UICKeyChainStore *Keychain = nil;

static int SshEncodeBuffer(unsigned char *pEncoding, int bufferLen, unsigned char *pBuffer)
{
  int adjustedLen = bufferLen, index;
  if (*pBuffer & 0x80) {
    adjustedLen++;
    pEncoding[4] = 0;
    index = 5;
  } else {
    index = 4;
  }
  pEncoding[0] = (unsigned char)(adjustedLen >> 24);
  pEncoding[1] = (unsigned char)(adjustedLen >> 16);
  pEncoding[2] = (unsigned char)(adjustedLen >> 8);
  pEncoding[3] = (unsigned char)(adjustedLen);
  memcpy(&pEncoding[index], pBuffer, bufferLen);
  return index + bufferLen;
}

// It is responsible to interface with OpenSSL library.
// It offers secure tokens.
@implementation SshRsa {
  RSA *_rsa;
  EVP_PKEY *_pkey;
}

+ (void)initialize
{
  // NOT deprecated.
  OpenSSL_add_all_algorithms();
}

- (SshRsa *)initFromPrivateKey:(NSString *)privateKey passphrase:(NSString *)passphrase
{
  self = [super init];
  const char *ckey = [privateKey UTF8String];

  // Create a read-only memory BIO
  BIO *fpem = BIO_new_mem_buf((void *)ckey, -1);
  const char *pp = (passphrase) ? [passphrase UTF8String] : NULL;
  _rsa = RSA_new();
  _pkey = EVP_PKEY_new();

  _rsa = PEM_read_bio_RSAPrivateKey(fpem, NULL, NULL, (void *)pp);
  BIO_free(fpem);

  if (!_rsa || !RSA_check_key(_rsa)) {
    return nil;
  }

  // Convert RSA to PKEY format
  // Initialise with both tied, we only have to release the rsa on dealloc
  if (!EVP_PKEY_assign_RSA(_pkey, _rsa)) {
    return nil;
  }

  return self;
}

- (SshRsa *)initWithLength:(int)bits
{
  self = [super init];
  _rsa = RSA_new();
  _pkey = EVP_PKEY_new();
  BIGNUM *bn = BN_new();

  // Exponent
  BN_set_word(bn, RSA_F4);

  // Generate key
  if (!RSA_generate_key_ex(_rsa, bits, bn, NULL)) {
    BN_free(bn);
    return nil;
  }

  BN_free(bn);
  // Convert RSA to PKEY format
  // Initialise with both tied, we only have to release the rsa on dealloc
  if (!EVP_PKEY_assign_RSA(_pkey, _rsa)) {
    return nil;
  }

  return self;
}

// Returns a PKCS#8 formatted key, with AEC encryption.
- (NSString *)privateKey
{
  return [self privateKeyWithPassphrase:nil];
}

- (NSString *)privateKeyWithPassphrase:(NSString *)passphrase
{
  BIO *fpem = BIO_new(BIO_s_mem());
  const char *pp = NULL;
  long pp_sz = 0;
  const EVP_CIPHER *cipher = NULL;

  if (passphrase.length) {
    pp = [passphrase UTF8String];
    pp_sz = strlen(pp);
    cipher = EVP_aes_256_cbc();
  }

  if (!PEM_write_bio_PKCS8PrivateKey(fpem, _pkey,
                                     cipher,
                                     (char *)pp, // NULL for no passphrase
                                     (int)pp_sz, NULL, NULL)) {
    BIO_free(fpem);
    return nil;
  }

  char *pkey;
  long sz = BIO_get_mem_data(fpem, &pkey);
  NSString *key = [[NSString alloc] initWithBytes:pkey length:sz encoding:NSUTF8StringEncoding];
  BIO_free(fpem);

  return key;
}

// Generate OpenSSH public key
- (NSString *)publicKey
{
  int nLen = 0, eLen = 0;
  int index = 0;
  unsigned char *pEncoding = NULL;
  int encodingLength = 0;
  unsigned char *nBytes = NULL, *eBytes = NULL;
  BIO *b64, *fpub;

  // reading the modulus
  nLen = BN_num_bytes(_rsa->n);
  nBytes = (unsigned char *)malloc(nLen);
  BN_bn2bin(_rsa->n, nBytes);

  // reading the public exponent
  eLen = BN_num_bytes(_rsa->e);
  eBytes = (unsigned char *)malloc(eLen);
  BN_bn2bin(_rsa->e, eBytes);

  encodingLength = 11 + 4 + eLen + 4 + nLen;
  // correct depending on the MSB of e and N
  if (eBytes[0] & 0x80) {
    encodingLength++;
  }
  if (nBytes[0] & 0x80) {
    encodingLength++;
  }

  pEncoding = (unsigned char *)malloc(encodingLength);
  memcpy(pEncoding, pSshHeader, 11);

  // Encoding exponent and modulus
  index = SshEncodeBuffer(&pEncoding[11], eLen, eBytes);
  index = SshEncodeBuffer(&pEncoding[11 + index], nLen, nBytes);

  free(nBytes);
  free(eBytes);

  b64 = BIO_new(BIO_f_base64());
  fpub = BIO_new(BIO_s_mem());
  BIO_set_flags(b64, BIO_FLAGS_BASE64_NO_NL);
  BIO_write(fpub, "ssh-rsa ", 8);
  BIO_flush(fpub);

  // Filter
  fpub = BIO_push(b64, fpub);
  BIO_write(fpub, pEncoding, encodingLength);
  BIO_write(fpub, '\0', 1);
  BIO_flush(fpub);
  fpub = BIO_pop(b64);

  BIO_free(b64);
  // Read and return public key
  char *pkey;
  long sz = BIO_get_mem_data(fpub, &pkey);
  NSString *key = [[NSString alloc] initWithBytes:pkey length:sz encoding:NSUTF8StringEncoding];

  // Free the BIO key memory
  BIO_free(fpub);

  return key;
}

- (void)dealloc
{
  RSA_free(_rsa);
}
@end

@implementation BKPubKey {
  NSString *_privateKeyRef;
  NSString *_publicKey;
}

+ (void)initialize
{
  // Maintain compatibility with previous version of the class
  [NSKeyedUnarchiver setClass:self forClassName:@"PKCard"];

  Keychain = [UICKeyChainStore keyChainStoreWithService:@"sh.blink.pkcard"];
  [BKPubKey loadIDS];
}

+ (instancetype)withID:(NSString *)ID
{
  // Find the ID and return it.
  for (BKPubKey *i in Identities) {
    if ([i->_ID isEqualToString:ID]) {
      return i;
    }
  }

  return nil;
}

+ (NSMutableArray *)all
{
  return Identities;
}

+ (BOOL)saveIDS
{
  // Save IDs to file
  return [NSKeyedArchiver archiveRootObject:Identities toFile:KeysURL.path];
}

+ (void)loadIDS
{
  if (DocumentsDirectory == nil) {
    //Identities = [[NSMutableArray alloc] init];
    DocumentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    KeysURL = [DocumentsDirectory URLByAppendingPathComponent:@"keys"];
  }

  // Load IDs from file
  if ((Identities = [NSKeyedUnarchiver unarchiveObjectWithFile:KeysURL.path]) == nil) {
    // Initialize the structure if it doesn't exist, with a default id_rsa key
    Identities = [[NSMutableArray alloc] init];
    SshRsa *defaultKey = [[SshRsa alloc] initWithLength:4096];
    [self saveCard:@"id_rsa" privateKey:defaultKey.privateKey publicKey:defaultKey.publicKey];
  }
}

+ (id)saveCard:(NSString *)ID privateKey:(NSString *)privateKey publicKey:(NSString *)publicKey
{
  if (!privateKey || !publicKey) {
    return nil;
  }
  // Save privateKey to storage
  // If the card already exists, then it is replaced
  NSString *privateKeyRef = [ID stringByAppendingString:@".pem"];
  if (![Keychain setString:privateKey forKey:privateKeyRef]) {
    return nil;
  }

  BKPubKey *card = [BKPubKey withID:ID];
  if (!card) {
    card = [[BKPubKey alloc] initWithID:ID privateKeyRef:privateKeyRef publicKey:publicKey];
    [Identities addObject:card];
  } else {
    card->_privateKeyRef = privateKeyRef;
    card->_publicKey = publicKey;
  }

  if (![BKPubKey saveIDS]) {
    // This should never fail, but it is kept for testing purposes.
    return nil;
  }

  return card;
}

+ (NSInteger)count
{
  return [Identities count];
}

- (id)initWithCoder:(NSCoder *)coder
{
  _ID = [coder decodeObjectForKey:@"ID"];
  _privateKeyRef = [coder decodeObjectForKey:@"privateKeyRef"];
  _publicKey = [coder decodeObjectForKey:@"publicKey"];

  return [self initWithID:_ID privateKeyRef:_privateKeyRef publicKey:_publicKey];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeObject:_ID forKey:@"ID"];
  [coder encodeObject:_privateKeyRef forKey:@"privateKeyRef"];
  [coder encodeObject:_publicKey forKey:@"publicKey"];
}

- (id)initWithID:(NSString *)ID privateKeyRef:(NSString *)privateKeyRef publicKey:(NSString *)publicKey
{
  self = [self init];
  if (self == nil)
    return nil;

  _ID = ID;
  _privateKeyRef = privateKeyRef;
  _publicKey = publicKey;

  return self;
}

- (NSString *)publicKey
{
  return _publicKey;
}

- (NSString *)privateKey
{
  return [Keychain stringForKey:_privateKeyRef];
}

- (BOOL)isEncrypted
{
  NSString *priv = [self privateKey];
  if ([priv rangeOfString:@"^Proc-Type: 4,ENCRYPTED\n"
                  options:NSRegularExpressionSearch]
        .location != NSNotFound)
    return YES;
  else if ([priv rangeOfString:@"^-----BEGIN ENCRYPTED PRIVATE KEY-----\n"
                       options:NSRegularExpressionSearch]
             .location != NSNotFound)
    return YES;
  else
    return NO;
}

@end
