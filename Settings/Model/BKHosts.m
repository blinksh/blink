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

#import "BKHosts.h"
#import "BKiCloudSyncHandler.h"
#import "UICKeyChainStore/UICKeyChainStore.h"
#import "BlinkPaths.h"

NSMutableArray *Hosts;

static UICKeyChainStore *Keychain = nil;

@implementation BKHosts

- (id)initWithCoder:(NSCoder *)coder
{
  _host = [coder decodeObjectForKey:@"host"];
  _hostName = [coder decodeObjectForKey:@"hostName"];
  _port = [coder decodeObjectForKey:@"port"];
  _user = [coder decodeObjectForKey:@"user"];
  _passwordRef = [coder decodeObjectForKey:@"passwordRef"];
  _key = [coder decodeObjectForKey:@"key"];
  _moshServer = [coder decodeObjectForKey:@"moshServer"];
  _moshPort = [coder decodeObjectForKey:@"moshPort"];
  _moshStartup = [coder decodeObjectForKey:@"moshStartup"];
  _prediction = [coder decodeObjectForKey:@"prediction"];
  _lastModifiedTime = [coder decodeObjectForKey:@"lastModifiedTime"];
  _iCloudRecordId = [coder decodeObjectForKey:@"iCloudRecordId"];
  _iCloudConflictDetected = [coder decodeObjectForKey:@"iCloudConflictDetected"];
  return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
  [encoder encodeObject:_host forKey:@"host"];
  [encoder encodeObject:_hostName forKey:@"hostName"];
  [encoder encodeObject:_port forKey:@"port"];
  [encoder encodeObject:_user forKey:@"user"];
  [encoder encodeObject:_passwordRef forKey:@"passwordRef"];
  [encoder encodeObject:_key forKey:@"key"];
  [encoder encodeObject:_moshServer forKey:@"moshServer"];
  [encoder encodeObject:_moshPort forKey:@"moshPort"];
  [encoder encodeObject:_moshStartup forKey:@"moshStartup"];
  [encoder encodeObject:_prediction forKey:@"prediction"];
  [encoder encodeObject:_lastModifiedTime forKey:@"lastModifiedTime"];
  [encoder encodeObject:_iCloudRecordId forKey:@"iCloudRecordId"];
  [encoder encodeObject:_iCloudConflictDetected forKey:@"iCloudConflictDetected"];
}

- (id)initWithHost:(NSString *)host hostName:(NSString *)hostName sshPort:(NSString *)sshPort user:(NSString *)user passwordRef:(NSString *)passwordRef hostKey:(NSString *)hostKey moshServer:(NSString *)moshServer moshPort:(NSString *)moshPort startUpCmd:(NSString *)startUpCmd prediction:(enum BKMoshPrediction)prediction
{
  self = [super init];
  if (self) {
    _host = host;
    _hostName = hostName;
    if (![sshPort isEqualToString:@""]) {
      _port = [NSNumber numberWithInt:sshPort.intValue];
    }
    _user = user;
    _passwordRef = passwordRef;
    _key = hostKey;
    if (![moshServer isEqualToString:@""]) {
      _moshServer = moshServer;
    }
    if (![moshPort isEqualToString:@""]) {
      _moshPort = [NSNumber numberWithInt:moshPort.intValue];
    }
    _moshStartup = startUpCmd;
    _prediction = [NSNumber numberWithInt:prediction];
  }
  return self;
}

- (NSString *)password
{
  if (!_passwordRef) {
    return nil;
  } else {
    return [Keychain stringForKey:_passwordRef];
  }
}

+ (void)initialize
{
  Keychain = [UICKeyChainStore keyChainStoreWithService:@"sh.blink.pwd"];
}

+ (instancetype)withHost:(NSString *)aHost
{
  for (BKHosts *host in Hosts) {
    if ([host->_host isEqualToString:aHost]) {
      return host;
    }
  }
  return nil;
}

+ (instancetype)withiCloudId:(CKRecordID *)record
{
  for (BKHosts *host in Hosts) {
    if ([host->_iCloudRecordId isEqual:record]) {
      return host;
    }
  }
  return nil;
}

+ (NSMutableArray *)all
{
  return Hosts;
}

+ (NSInteger)count
{
  return [Hosts count];
}

+ (BOOL)saveHosts
{
  // Save IDs to file
  return [NSKeyedArchiver archiveRootObject:Hosts toFile:[BlinkPaths blinkHostsFile]];
}

+ (instancetype)saveHost:(NSString *)host withNewHost:(NSString *)newHost hostName:(NSString *)hostName sshPort:(NSString *)sshPort user:(NSString *)user password:(NSString *)password hostKey:(NSString *)hostKey moshServer:(NSString *)moshServer moshPort:(NSString *)moshPort startUpCmd:(NSString *)startUpCmd prediction:(enum BKMoshPrediction)prediction
{
  NSString *pwdRef = @"";
  if (password) {
    pwdRef = [newHost stringByAppendingString:@".pwd"];
    [Keychain setString:password forKey:pwdRef];
  }

  BKHosts *bkHost = [BKHosts withHost:host];
  // Save password to keychain if it changed
  if (!bkHost) {
    bkHost = [[BKHosts alloc] initWithHost:newHost hostName:hostName sshPort:sshPort user:user passwordRef:pwdRef hostKey:hostKey moshServer:moshServer moshPort:moshPort startUpCmd:startUpCmd prediction:prediction];
    [Hosts addObject:bkHost];
  } else {
    bkHost.host = newHost;
    bkHost.hostName = hostName;
    if (![sshPort isEqualToString:@""]) {
      bkHost.port = [NSNumber numberWithInt:sshPort.intValue];
    } else {
      bkHost.port = nil;
    }
    bkHost.user = user;
    bkHost.passwordRef = pwdRef;
    bkHost.key = hostKey;
    bkHost.moshServer = moshServer;
    if (![moshPort isEqualToString:@""]) {
      bkHost.moshPort = [NSNumber numberWithInt:moshPort.intValue];
    }else{
      bkHost.moshPort = nil;
    }
    bkHost.moshStartup = startUpCmd;
    bkHost.prediction = [NSNumber numberWithInt:prediction];
  }
  if (![BKHosts saveHosts]) {
    return nil;
  }
  return bkHost;
}

+ (void)updateHost:(NSString *)host withiCloudId:(CKRecordID *)iCloudId andLastModifiedTime:(NSDate *)lastModifiedTime
{
  BKHosts *bkHost = [BKHosts withHost:host];
  if (bkHost) {
    bkHost.iCloudRecordId = iCloudId;
    bkHost.lastModifiedTime = lastModifiedTime;
  }
  [BKHosts saveHosts];
}

+ (void)markHost:(NSString *)host forRecord:(CKRecord *)record withConflict:(BOOL)hasConflict
{
  BKHosts *bkHost = [BKHosts withHost:host];
  if (bkHost) {
    if (hasConflict && record != nil) {
      BKHosts *conflictCopy = [BKHosts hostFromRecord:record];
      conflictCopy.iCloudRecordId = record.recordID;
      conflictCopy.lastModifiedTime = record.modificationDate;
      bkHost.iCloudConflictCopy = conflictCopy;
    }
    if (!hasConflict) {
      bkHost.iCloudConflictCopy = nil;
    }
    bkHost.iCloudConflictDetected = [NSNumber numberWithBool:hasConflict];
  }
  [BKHosts saveHosts];
}

+ (void)loadHosts
{
  // Load IDs from file
  if ((Hosts = [NSKeyedUnarchiver unarchiveObjectWithFile:[BlinkPaths blinkHostsFile]]) == nil) {
    // Initialize the structure if it doesn't exist
    Hosts = [[NSMutableArray alloc] init];
  }
}

+ (NSString *)predictionStringForRawValue:(int)rawValue
{
  NSString *predictionString = nil;
  switch (rawValue) {
    case BKMoshPredictionAdaptive:
      predictionString = @"Adaptive";
      break;
    case BKMoshPredictionAlways:
      predictionString = @"Always";
      break;
    case BKMoshPredictionNever:
      predictionString = @"Never";
      break;
    case BKMoshPredictionExperimental:
      predictionString = @"Experimental";
      break;

    default:
      break;
  }
  return predictionString;
}

+ (enum BKMoshPrediction)predictionValueForString:(NSString *)predictionString
{
  enum BKMoshPrediction value = BKMoshPredictionUnknown;
  if ([predictionString isEqualToString:@"Adaptive"]) {
    value = BKMoshPredictionAdaptive;
  } else if ([predictionString isEqualToString:@"Always"]) {
    value = BKMoshPredictionAlways;
  } else if ([predictionString isEqualToString:@"Never"]) {
    value = BKMoshPredictionNever;
  } else if ([predictionString isEqualToString:@"Experimental"]) {
    value = BKMoshPredictionExperimental;
  }
  return value;
}

+ (NSMutableArray *)predictionStringList
{
  return [NSMutableArray arrayWithObjects:@"Adaptive", @"Always", @"Never", @"Experimental", nil];
}

+ (CKRecord *)recordFromHost:(BKHosts *)host
{

  CKRecord *hostRecord = nil;
  if (host.iCloudRecordId) {
    hostRecord = [[CKRecord alloc] initWithRecordType:@"BKHost" recordID:host.iCloudRecordId];
  } else {
    hostRecord = [[CKRecord alloc] initWithRecordType:@"BKHost"];
  }
  [hostRecord setValue:host.host forKey:@"host"];
  [hostRecord setValue:host.hostName forKey:@"hostName"];
  [hostRecord setValue:host.key forKey:@"key"];
  if (host.moshPort)
    [hostRecord setValue:host.moshPort forKey:@"moshPort"];
  [hostRecord setValue:host.moshServer forKey:@"moshServer"];
  [hostRecord setValue:host.moshStartup forKey:@"moshStartup"];
  [hostRecord setValue:host.password forKey:@"password"];
  [hostRecord setValue:host.passwordRef forKey:@"passwordRef"];
  if (host.port)
    [hostRecord setValue:host.port forKey:@"port"];
  [hostRecord setValue:host.prediction forKey:@"prediction"];
  [hostRecord setValue:host.user forKey:@"user"];
  return hostRecord;
}

+ (BKHosts *)hostFromRecord:(CKRecord *)hostRecord
{
  BKHosts *host = [[BKHosts alloc] initWithHost:[hostRecord valueForKey:@"host"] hostName:[hostRecord valueForKey:@"hostName"] sshPort:[hostRecord valueForKey:@"port"] ? [[hostRecord valueForKey:@"port"] stringValue] : @"" user:[hostRecord valueForKey:@"user"] passwordRef:[hostRecord valueForKey:@"passwordRef"] hostKey:[hostRecord valueForKey:@"key"] moshServer:[hostRecord valueForKey:@"moshServer"] moshPort:[hostRecord valueForKey:@"moshPort"] ? [[hostRecord valueForKey:@"moshPort"] stringValue] : @"" startUpCmd:[hostRecord valueForKey:@"moshStartup"] prediction:[[hostRecord valueForKey:@"prediction"] intValue]];
  return host;
}

@end
