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

#import <Foundation/Foundation.h>
#import "BKPubKey.h"
#import "UICKeyChainStore.h"

#import "BlinkPaths.h"
#import <openssl/rsa.h>
#import <OpenSSH/sshbuf.h>
#import <OpenSSH/sshkey.h>
#import <OpenSSH/ssherr.h>
#import "Blink-Swift.h"

NSMutableArray *Identities;

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
  for (BKPubKey *i in Identities) {
    if ([i->_ID isEqualToString:ID]) {
      return i;
    }
  }

  return nil;
}

+ (NSArray *)all
{
  return [Identities copy];
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
      [self saveDefaultKey];
    });
  }
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
  [Identities addObject:pubKey];
  [BKPubKey saveIDS];
}

+ (nullable id)saveInKeychainWithID:(nonnull NSString *)ID
                         privateKey:(nonnull NSString *)privateKey
                          publicKey:(nonnull NSString *)publicKey
{
  if (!ID || !privateKey || !publicKey) {
    return nil;
  }
  
  UICKeyChainStore *keychain = __get_keychain();

  NSError *error;
  
  BKPubKey *card = [BKPubKey withID:ID];
  if (card) {
    card->_publicKey = publicKey;
    card->_storageType = BKPubKeyStorageTypeKeyChain;
    NSString *privateKeyRef = [card _privateKeyKeychainRef];

    if (![keychain setString:privateKey forKey:privateKeyRef error:&error]) {
      return nil;
    }
  } else {
    card = [[BKPubKey alloc] initWithID:ID publicKey:publicKey];
    card->_storageType = BKPubKeyStorageTypeKeyChain;
    
    NSString *privateKeyRef = [card _privateKeyKeychainRef];
    
    if (![keychain setString:privateKey forKey:privateKeyRef error:&error]) {
      return nil;
    }
    
    [Identities addObject:card];
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
  self = [super init];
  if (!self) {
    return nil;
  }
  _ID = [coder decodeObjectForKey:@"ID"];
  _tag = [coder decodeObjectForKey:@"tag"];
  _storageType = [coder decodeInt64ForKey:@"storageType"];
  
  _keyType = [coder decodeObjectForKey:@"keyType"];
  _certType = [coder decodeObjectForKey:@"certType"];
  
  _privateKeyRef = [coder decodeObjectForKey:@"privateKeyRef"];
  _publicKey = [coder decodeObjectForKey:@"publicKey"];
  
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
    @"ecdsa-sha2-nistp521-cert-v01@openssh.com": @"ECDSA-CERT"
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
  [Identities removeObject:self];
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
