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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

extern const NSString *BK_KEYTYPE_RSA;
extern const NSString *BK_KEYTYPE_DSA;
extern const NSString *BK_KEYTYPE_ECDSA;
extern const NSString *BK_KEYTYPE_Ed25519;

@interface Pki : NSObject

- (Pki *)initRSAWithLength:(int)bits;
- (Pki *)initWithType:(NSString *)type andBits:(int)bits;
- (NSString *)privateKey;
- (NSString *)publicKeyWithComment:(NSString*)comment;
- (const NSString *)keyTypeName;

+ (NSArray<NSString *> *)supportedKeyTypes;
+ (void)importPrivateKey:(NSString *)privateKey controller:(UIViewController *)controller andCallback: (void(^)(Pki * , NSString *))callback;

@end

@interface BKPubKey : NSObject <NSSecureCoding, UIActivityItemSource>

@property NSString *ID;
@property (readonly) NSString *privateKey;
@property (readonly) NSString *publicKey;

+ (void)initialize;
+ (instancetype)withID:(NSString *)ID;
+ (void)loadIDS;
+ (BOOL)saveIDS;
+ (id)saveCard:(NSString *)ID privateKey:(NSString *)privateKey publicKey:(NSString *)publicKey;
+ (NSMutableArray *)all;
+ (NSInteger)count;
- (BOOL)isEncrypted;

- (NSString *)publicKey;
- (NSString *)privateKey;

@end

// Responsible of the lifecycle of the IDCards within the system.
// Offers a directory to the rest, in the same way that you wouldn't offer everything in a file interface.
// Class methods can give us this, then we can connect the TableViewController for rendering, extending them with
// a Decorator (or in this case maybe a custom View that represents the Cell)
