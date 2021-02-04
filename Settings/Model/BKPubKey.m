////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2018 Blink Mobile Shell Project
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

#include <libssh/callbacks.h>


#import "BKPubKey.h"
#import "UICKeyChainStore.h"

#import "BlinkPaths.h"
#import <openssl/rsa.h>
#import <OpenSSH/sshbuf.h>
#import <OpenSSH/sshkey.h>
#import <OpenSSH/ssherr.h>

const NSString *BK_KEYTYPE_RSA = @"RSA";
const NSString *BK_KEYTYPE_DSA = @"DSA";
const NSString *BK_KEYTYPE_ECDSA = @"ECDSA";
const NSString *BK_KEYTYPE_ECDSA_P256 = @"ECDSA P256";
const NSString *BK_KEYTYPE_ECDSA_P384 = @"ECDSA P384";
const NSString *BK_KEYTYPE_ECDSA_P521 = @"ECDSA P521";

const NSString *BK_KEYTYPE_Ed25519 = @"Ed25519";

struct blink_ssh_key_struct {
  enum ssh_keytypes_e type;
  int flags;
  const char *type_c; /* Don't free it ! it is static */
  int ecdsa_nid;
  DSA *dsa;
  RSA *rsa;
  EC_KEY *ecdsa;
  u_char  *ed25519_pubkey;
  u_char  *ed25519_privkey;
  void *cert;
  enum ssh_keytypes_e cert_type;
};

NSMutableArray *Identities;

static UICKeyChainStore *__get_keychain() {
  return [UICKeyChainStore keyChainStoreWithService:@"sh.blink.pkcard"];
}

@implementation Pki {
  ssh_key _ssh_key;
}

NSString *__get_passphrase(UIViewController *ctrl) {
  
  dispatch_semaphore_t dsema = dispatch_semaphore_create(0);
  __block NSString *result = NULL;
  
  dispatch_async(dispatch_get_main_queue(),^{
    UIAlertController *passphraseRequest = [UIAlertController alertControllerWithTitle:@"Encrypted key"
                                                                               message:@"Please insert passphrase"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
    [passphraseRequest addTextFieldWithConfigurationHandler:^(UITextField *textField) {
      textField.placeholder = NSLocalizedString(@"Enter passphrase", @"Passphrase");
      textField.secureTextEntry = YES;
    }];
    
    
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *_Nonnull action) {
                                                 UITextField *passphrase = passphraseRequest.textFields.lastObject;
                                                 result = passphrase.text ?: @"";
                                                 dispatch_semaphore_signal(dsema);
                                               }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel"
                                                 style:UIAlertActionStyleCancel
                                               handler:^(UIAlertAction *_Nonnull action) {
                                                 result = nil;
                                                 dispatch_semaphore_signal(dsema);
                                               }];
    
    [passphraseRequest addAction:cancel];
    [passphraseRequest addAction:ok];
    [ctrl presentViewController:passphraseRequest animated:YES completion:nil];
  });
  
  dispatch_semaphore_wait(dsema, DISPATCH_TIME_FOREVER);
  
  return result;
}

+ (void)importPrivateKey:(NSString *)privateKey controller:(UIViewController *)controller andCallback: (void(^)(Pki *, NSString *))callback
{
  dispatch_async(dispatch_get_global_queue(0, 0), ^{
    
    struct sshbuf *b = sshbuf_from(privateKey.UTF8String, [privateKey lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    
    if (b == NULL) {
      dispatch_sync(dispatch_get_main_queue(), ^{
        callback(nil, nil);
      });
      return;
    }
    
    struct sshkey *keyp = NULL;
    char *commepntp = NULL;
    int rcs = 0;
    NSString *passphrase = @"";
    for (;;) {
      rcs = sshkey_parse_private_fileblob(b, passphrase.UTF8String, &keyp, &commepntp);
      if (rcs == SSH_ERR_KEY_WRONG_PASSPHRASE) {
        passphrase = __get_passphrase(controller);
        if (passphrase == nil) {
          sshbuf_free(b);
          dispatch_sync(dispatch_get_main_queue(), ^{
            callback(nil, nil);
          });
          return;
        }
        continue;
      }
      
      if (rcs == SSH_ERR_SUCCESS) {
        break;
      }
      
      dispatch_sync(dispatch_get_main_queue(), ^{
        callback(nil, nil);
      });
      return;
    }

    sshbuf_free(b);
    ssh_key skey = ssh_key_new();
    int bits = 0;
    struct blink_ssh_key_struct *bkey = (struct blink_ssh_key_struct *)skey;
    bkey->flags = 0x0002 | 0x0001;
    bkey->dsa = keyp->dsa;
    bkey->rsa = keyp->rsa;
    bkey->ecdsa = keyp->ecdsa;
    bkey->ecdsa_nid = keyp->ecdsa_nid;
    bkey->ed25519_pubkey = keyp->ed25519_pk;
    bkey->ed25519_privkey = keyp->ed25519_sk;
    switch (keyp -> type) {
      case KEY_RSA:
        bkey->type = SSH_KEYTYPE_RSA;
        bkey->type_c = ssh_key_type_to_char(bkey->type);
        break;
      case KEY_DSA:
        bkey->type = SSH_KEYTYPE_DSS;
        bkey->type_c = ssh_key_type_to_char(bkey->type);
        break;
      case KEY_ECDSA:
        bits = sshkey_curve_nid_to_bits(keyp->ecdsa_nid);
        if (bits == 256) {
          bkey->type = SSH_KEYTYPE_ECDSA_P256;
        } else if (bits == 384) {
          bkey->type = SSH_KEYTYPE_ECDSA_P384;
        } else if (bits == 521) {
          bkey->type = SSH_KEYTYPE_ECDSA_P521;
        } else {
          bkey->type = SSH_KEYTYPE_ECDSA;
        }
        
        bkey->type_c = ssh_pki_key_ecdsa_name(skey);
        break;
      case KEY_ED25519:
        bkey->type = SSH_KEYTYPE_ED25519;
        bkey->type_c = ssh_key_type_to_char(bkey->type);
        break;
      default:
        ssh_key_free(skey);
        if (commepntp != NULL) {
          free(commepntp);
        }
        free(keyp);
        dispatch_sync(dispatch_get_main_queue(), ^{
          callback(nil, nil);
        });
        return;
    }
    free(keyp);
    
    
    Pki *pki = [[Pki alloc] init];
    pki->_ssh_key = skey;
    dispatch_async(dispatch_get_main_queue(), ^{
      NSString *comment = nil;
      if (commepntp != NULL) {
        comment = @(commepntp);
        free(commepntp);
      }
      callback(pki, comment);
    });
  });
}

+ (NSArray<const NSString *> *)supportedKeyTypes {
  return @[BK_KEYTYPE_DSA, BK_KEYTYPE_RSA, BK_KEYTYPE_ECDSA, BK_KEYTYPE_Ed25519];
}

- (const NSString *)keyTypeName {
  enum ssh_keytypes_e type = ssh_key_type(_ssh_key);
  switch (type) {
    case SSH_KEYTYPE_DSS:
      return BK_KEYTYPE_DSA;
    case SSH_KEYTYPE_RSA:
    case SSH_KEYTYPE_RSA1:
      return BK_KEYTYPE_RSA;
    case SSH_KEYTYPE_ECDSA:
      return BK_KEYTYPE_ECDSA;
    case SSH_KEYTYPE_ECDSA_P256:
      return BK_KEYTYPE_ECDSA_P256;
    case SSH_KEYTYPE_ECDSA_P384:
      return BK_KEYTYPE_ECDSA_P384;
    case SSH_KEYTYPE_ECDSA_P521:
      return BK_KEYTYPE_ECDSA_P521;
    case SSH_KEYTYPE_ED25519:
      return BK_KEYTYPE_Ed25519;
    default:
      return @(ssh_key_type_to_char(type));
  }
}

- (enum ssh_keytypes_e)_typeFormString:(const NSString *)name {
  if ([name isEqual:BK_KEYTYPE_RSA]) {
    return SSH_KEYTYPE_RSA;
  } else if ([name isEqual: BK_KEYTYPE_ECDSA]) {
    return SSH_KEYTYPE_ECDSA;
  } else if ([name isEqual: BK_KEYTYPE_Ed25519]) {
    return SSH_KEYTYPE_ED25519;
  } else if ([name isEqual:BK_KEYTYPE_DSA]) {
    return SSH_KEYTYPE_DSS;
  }
  
  return ssh_key_type_from_name(name.UTF8String);
}


- (Pki *)initRSAWithLength:(int)bits
{
  self = [super init];
  
  int rc = ssh_pki_generate(SSH_KEYTYPE_RSA, bits, &_ssh_key);
  if (rc != SSH_OK) {
    return nil;
  }
  
  return self;
}

- (Pki *)initWithType:(NSString *)type andBits:(int)bits
{
  self = [super init];
  
  int rc = ssh_pki_generate([self _typeFormString:type], bits, &_ssh_key);
  if (rc != SSH_OK) {
    return nil;
  }
  
  return self;
}

- (NSString *)privateKey
{
  char *b64_key = NULL;
  
  int rc =ssh_pki_export_privkey_base64(_ssh_key, NULL, NULL, NULL, &b64_key);
  if (rc != SSH_OK) {
    return nil;
  }
  
  NSString *key = [[NSString alloc] initWithUTF8String:b64_key];
  ssh_string_free_char(b64_key);
  
  return key;
}

// Generate OpenSSH or PEM public key
- (NSString *)publicKeyWithComment:(NSString*)comment
{
  char *b64_key = NULL;
  int rc = ssh_pki_export_pubkey_base64(_ssh_key, &b64_key);
  if (rc != SSH_OK) {
    return nil;
  }

  NSString *key = [[NSString alloc] initWithUTF8String:b64_key];
  ssh_string_free_char(b64_key);

  enum ssh_keytypes_e key_type = ssh_key_type(_ssh_key);
  NSString *keyType = nil;
  if (key_type == SSH_KEYTYPE_ECDSA) {
    const char *name = ssh_pki_key_ecdsa_name(_ssh_key);
    keyType = @(name);
  } else {
    const char *key_type_chars = ssh_key_type_to_char(key_type);
    keyType = @(key_type_chars);
  }
  
  NSString *commentedKey = [NSString stringWithFormat:@"%@ %@ %@", keyType, key, comment];
  return commentedKey;
}

- (void)dealloc
{
  if (_ssh_key) {
    ssh_key_free(_ssh_key);
    _ssh_key = NULL;
  }
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
  return [NSKeyedArchiver archiveRootObject:Identities toFile:[BlinkPaths blinkKeysFile]];
}

+ (void)loadIDS
{
  // Load IDs from file
  if ((Identities = [NSKeyedUnarchiver unarchiveObjectWithFile:[BlinkPaths blinkKeysFile]]) == nil) {
    // Initialize the structure if it doesn't exist, with a default id_rsa key
    Identities = [[NSMutableArray alloc] init];
    
    // Create default key in next main queue step in order to speedup app start.
    dispatch_async(dispatch_get_main_queue(), ^{
      Pki *defaultKey = [[Pki alloc] initRSAWithLength:4096];
      [self saveCard:@"id_rsa" privateKey:defaultKey.privateKey publicKey:[defaultKey publicKeyWithComment:@""]];
    });
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
  UICKeyChainStore *keychain = __get_keychain();
  NSError *error;
  if (![keychain setString:privateKey forKey:privateKeyRef error:&error]) {
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
  UICKeyChainStore *keychain = __get_keychain();
  return [keychain stringForKey:_privateKeyRef];
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

// UIActivityItemSource methods
- (id)activityViewControllerPlaceholderItem:(UIActivityViewController *)activityViewController
{
  return _publicKey;
}

- (id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(UIActivityType)activityType
{
  if ([activityType  isEqualToString:UIActivityTypeMail] || [activityType isEqualToString:UIActivityTypeAirDrop]) {
    // Create a file to return if sharing through Mail or AirDrop
    NSString *tempFilename = [NSString stringWithFormat:@"%@.pub", _ID];
    NSString *publicKeyString = _publicKey;
    
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingString:tempFilename]];
    NSData *data = [publicKeyString dataUsingEncoding:NSUTF8StringEncoding];
    
    [data writeToURL:url atomically:NO];
    
    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
      // Delete the file when
      NSError *errorBlock;
      if([[NSFileManager defaultManager] removeItemAtURL:url error:&errorBlock] == NO) {
        NSLog(@"Error deleting temporary public key file %@",errorBlock);
        return;
      }
    }];
    
    return url;
  }
  return _publicKey;
}

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController
              subjectForActivityType:(UIActivityType)activityType
{
  return [NSString stringWithFormat:@"Blink Public Key: %@", _ID];
}

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController dataTypeIdentifierForActivityType:(UIActivityType)activityType
{
  return @"public.text";
}

@end
