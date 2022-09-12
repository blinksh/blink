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

//#include <libssh/callbacks.h>

#import <Foundation/Foundation.h>
#import "BKPubKey.h"
#import "BKMiniLog.h"
#import "UICKeyChainStore.h"

#import <BlinkConfig/BlinkConfig-Swift.h>

#import "BlinkPaths.h"
//#import <openssl/rsa.h>
//#import <OpenSSH/sshbuf.h>
//#import <OpenSSH/sshkey.h>
//#import <OpenSSH/ssherr.h>
//#import "Blink-Swift.h"

NSMutableArray *__identities;

const NSString * __keychainService = @"sh.blink.pkcard";

static UICKeyChainStore *__get_keychain() {
  return [UICKeyChainStore keyChainStoreWithService: __keychainService];
}

@implementation BKPubKey {
  NSString *_privateKeyRef;
  NSString *_tag;
}


+ (void)initialize
{
  // Maintain compatibility with previous version of the class
  [NSKeyedUnarchiver setClass:self forClassName:@"PKCard"];
}

+ (const NSString *)keychainService {
  return __keychainService;
}

+ (instancetype)withID:(NSString *)ID
{
  // Find the ID and return it.
  for (BKPubKey *i in __identities) {
    if ([i->_ID isEqualToString:ID]) {
      return i;
    }
  }

  return nil;
}

+ (NSArray *)all
{
  if (!__identities.count) {
    [self loadIDS];
  }
  return [__identities copy];
}

+ (BOOL)saveIDS {
  NSError *error = nil;
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:__identities
                                       requiringSecureCoding:YES
                                                       error:&error];
  if (error || !data) {
    NSLog(@"[BKPubKey] Failed to archive to data: %@", error);
    return NO;
  }
  
  BOOL result = [data writeToFile:[BlinkPaths blinkKeysFile]
                          options:NSDataWritingAtomic | NSDataWritingFileProtectionNone
                            error:&error];
  
  if (error || !result) {
    NSLog(@"[BKPubKey] Failed to save data to file: %@", error);
    return NO;
  }
  
  return result;
}

+ (void)loadIDS {
  __identities = [[NSMutableArray alloc] init];
  
  NSError *error = nil;
  NSData *data = [NSData dataWithContentsOfFile:[BlinkPaths blinkKeysFile]
                                        options:NSDataReadingMappedIfSafe
                                          error:&error];
  if (error || !data) {
    NSLog(@"[BKPubKey] Failed to load data: %@", error);
    return;
  }

  NSArray *result =
    [NSKeyedUnarchiver unarchivedArrayOfObjectsOfClasses:[NSSet setWithObjects:BKPubKey.class, nil]
                                                fromData:data
                                                   error:&error];
  
  if (error || !result) {
    NSLog(@"[BKPubKey] Failed to unarchive data: %@", error);
    return;
  }
  
  __identities = [result mutableCopy];
}

- (nullable instancetype)initWithID:(NSString *)ID
                                tag:(nonnull NSString *)tag
                          publicKey:(NSString *)publicKey
                            keyType:(NSString *)keyType
                           certType:(NSString *)certType
                        storageType:(BKPubKeyStorageType)storageType {

  if (self = [super init]) {
    _ID = ID;
    _tag = tag;
    _publicKey = publicKey;
    _keyType = keyType;
    _certType = certType;
    _storageType = storageType;
  }
  
  return self;
}

+ (void)addCard:(BKPubKey *)pubKey {
  [__identities addObject:pubKey];
  [BKPubKey saveIDS];
}

+ (NSInteger)count
{
  return [__identities count];
}

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (id)initWithCoder:(NSCoder *)coder
{
  self = [super init];
  if (!self) {
    return self;
  }
  NSSet *strings = [NSSet setWithObjects:NSString.class, nil];
//  NSSet *numbers = [NSSet setWithObjects:NSNumber.class, nil];
  
  _ID = [coder decodeObjectOfClasses:strings forKey:@"ID"];
  _tag = [coder decodeObjectOfClasses:strings forKey:@"tag"];
  _storageType = [coder decodeInt64ForKey:@"storageType"];
  
  _keyType = [coder decodeObjectOfClasses:strings forKey:@"keyType"];
  _certType = [coder decodeObjectOfClasses:strings forKey:@"certType"];
  
  _privateKeyRef = [coder decodeObjectOfClasses:strings forKey:@"privateKeyRef"];
  _publicKey = [coder decodeObjectOfClasses:strings forKey:@"publicKey"];
  
  if (!_tag) {
    _tag = [NSProcessInfo processInfo].globallyUniqueString;
  }
  
  if (!_keyType) {
    _keyType = [BKPubKey _shortKeyTypeNameFromSshKeyTypeName:[[_publicKey componentsSeparatedByString:@" "] firstObject]];
  }
  
  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeObject:_ID forKey:@"ID"];
  [coder encodeObject:_tag forKey:@"tag"];
  [coder encodeInt64:_storageType forKey:@"storageType"];
  
  [coder encodeObject:_keyType forKey:@"keyType"];
  [coder encodeObject:_certType forKey:@"certType"];
  
  [coder encodeObject:_privateKeyRef forKey:@"privateKeyRef"];
  [coder encodeObject:_publicKey forKey:@"publicKey"];
}

+ (NSString *)_shortKeyTypeNameFromSshKeyTypeName:(NSString *)keyTypeName {
  // https://github.com/openssh/openssh-portable/blob/master/sshkey.c#L106
  NSDictionary *map = @{
    @"ssh-ed25519": @"ED25519",
    @"ssh-ed25519-cert-v01@openssh.com": @"ED25519-CERT",
    @"ssh-rsa": @"RSA",
    @"rsa-sha2-256": @"RSA",
    @"rsa-sha2-512": @"RSA",
    @"ssh-dss": @"DSA",
    @"ecdsa-sha2-nistp256": @"ECDSA",
    @"ecdsa-sha2-nistp384": @"ECDSA",
    @"ecdsa-sha2-nistp521": @"ECDSA",
    @"ssh-rsa-cert-v01@openssh.com": @"RSA-CERT",
    @"rsa-sha2-256-cert-v01@openssh.com": @"RSA-CERT",
    @"rsa-sha2-512-cert-v01@openssh.com": @"RSA-CERT",
    @"ssh-dss-cert-v01@openssh.com": @"DSA-CERT",
    @"ecdsa-sha2-nistp256-cert-v01@openssh.com": @"ECDSA-CERT",
    @"ecdsa-sha2-nistp384-cert-v01@openssh.com": @"ECDSA-CERT",
    @"ecdsa-sha2-nistp521-cert-v01@openssh.com": @"ECDSA-CERT",
    // SK
    @"sk-ecdsa-sha2-nistp256@openssh.com" : @"ECDSA-SK",
    @"sk-ecdsa-sha2-nistp256-cert-v01@openssh.com" : @"ECDSA-SK-CERT",
  };
  return map[keyTypeName];
}

- (id)initWithID:(NSString *)ID publicKey:(NSString *)publicKey
{
  self = [self init];
  if (self == nil)
    return nil;

  _ID = ID;
  _tag = [[NSProcessInfo processInfo] globallyUniqueString];
  _privateKeyRef = nil;
  _publicKey = publicKey;

  return self;
}

- (nullable NSString *)loadCertificate {
  UICKeyChainStore *keychain = __get_keychain();
  return [keychain stringForKey:[self _certificateKeychainRef]];
}

- (void)storePrivateKeyInKeychain:(NSString *) privateKey {
  UICKeyChainStore *keychain = __get_keychain();
  [keychain setString:privateKey forKey:[self _privateKeyKeychainRef]];
}

- (void)storeCertificateInKeychain:(nullable NSString *) certificate {
  UICKeyChainStore *keychain = __get_keychain();
  NSString *certRef = [self _certificateKeychainRef];
  if (certificate) {
    _certType = [BKPubKey _shortKeyTypeNameFromSshKeyTypeName:[[certificate componentsSeparatedByString:@" "] firstObject]];
    [keychain setString:certificate forKey: certRef];
  } else {
    [keychain removeItemForKey:certRef];
    _certType = nil;
  }
}

- (nullable NSString *)privateKey {
  return [self loadPrivateKey];
}

- (nullable NSString *)loadPrivateKey
{
  // Legacy access via privateKeyRef
  if (_privateKeyRef) {
    UICKeyChainStore *keychain = __get_keychain();
    return [keychain stringForKey:_privateKeyRef];
  }
  
  switch (_storageType) {
    case BKPubKeyStorageTypeiCloudKeyChain:
    case BKPubKeyStorageTypeKeyChain: {
      UICKeyChainStore *keychain = __get_keychain();
      return [keychain stringForKey:[self _privateKeyKeychainRef]];
      break;
    }
    case BKPubKeyStorageTypeSecureEnclave:
      return nil;
    default:
      return nil;
  }
}

- (NSString *)_certificateKeychainRef {
  return [NSString stringWithFormat: @"%@-cert.pub", _tag];
}

- (NSString *)_privateKeyKeychainRef {
  return [NSString stringWithFormat: @"%@.pem", _tag];
}

- (BOOL)isEncrypted
{
  NSString *priv = [self loadPrivateKey];
  if ([priv rangeOfString:@"^Proc-Type: 4,ENCRYPTED\n"
                  options:NSRegularExpressionSearch]
      .location != NSNotFound) {
    return YES;
  }
  else if ([priv rangeOfString:@"^-----BEGIN ENCRYPTED PRIVATE KEY-----\n"
                       options:NSRegularExpressionSearch]
             .location != NSNotFound) {
    return YES;
  }
  else {
    return NO;
  }
}

- (void)removeCard {
  if (_storageType == BKPubKeyStorageTypeKeyChain) {
    UICKeyChainStore * kc = __get_keychain();
    [kc removeItemForKey:[self _certificateKeychainRef]];
    [kc removeItemForKey:[self _privateKeyKeychainRef]];
  }
  [__identities removeObject:self];
  [BKPubKey saveIDS];
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
