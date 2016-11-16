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

#import <Foundation/Foundation.h>
@import CloudKit;
enum BKMoshPrediction {
  BKMoshPredictionAdaptive,
  BKMoshPredictionAlways,
  BKMoshPredictionNever,
  BKMoshPredictionExperimental,
  BKMoshPredictionUnknown
};

@interface BKHosts : NSObject <NSCoding>

@property (nonatomic, strong) NSString *host;
@property (nonatomic, strong) NSString *hostName;
@property (nonatomic, strong) NSNumber *port;
@property (nonatomic, strong) NSString *user;
@property (nonatomic, strong) NSString *passwordRef;
@property (readonly) NSString *password;
@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) NSString *moshServer;
@property (nonatomic, strong) NSNumber *moshPort;
@property (nonatomic, strong) NSString *moshStartup;
@property (nonatomic, strong) NSNumber *prediction;
@property (nonatomic, strong) CKRecordID *iCloudRecordId;
@property (nonatomic, strong) NSDate *lastModifiedTime;
@property (nonatomic, strong) NSNumber *iCloudConflictDetected;

+ (void)initialize;
+ (instancetype)withHost:(NSString *)ID;
+ (BOOL)saveHosts;
+ (instancetype)saveHost:(NSString *)host withNewHost:(NSString *)newHost hostName:(NSString *)hostName sshPort:(NSString *)sshPort user:(NSString *)user password:(NSString *)password hostKey:(NSString *)hostKey moshServer:(NSString *)moshServer moshPort:(NSString *)moshPort startUpCmd:(NSString *)startUpCmd prediction:(enum BKMoshPrediction)prediction;
+ (void)saveHost:(NSString*)host withiCloudId:(CKRecordID*)iCloudId andLastModifiedTime:(NSDate*)lastModifiedTime;
+ (void)markHost:(NSString*)host withConflict:(BOOL)hasConflict;
+ (NSMutableArray *)all;
+ (NSInteger)count;
+ (NSString *)predictionStringForRawValue:(int)rawValue;
+ (enum BKMoshPrediction)predictionValueForString:(NSString *)predictionString;
+ (NSMutableArray *)predictionStringList;
+ (CKRecord*)recordFromHost:(BKHosts*)host;
+ (BKHosts*)hostFromRecord:(CKRecord*)hostRecord;
+ (instancetype)withiCloudId:(CKRecordID *)record;
@end
