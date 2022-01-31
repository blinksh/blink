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

#import "BKiCloudSyncHandler.h"
#import "BKHosts.h"
#import "BKPubKey.h"
#import "BKUserConfigurationManager.h"
#import "Reachability.h"
#import "BlinkPaths.h"
#import <BlinkConfig/XCConfig.h>

@import CloudKit;
@import UIKit;


NSString const *BKiCloudSyncDeletedHosts = @"deletedHosts";
NSString const *BKiCloudSyncDeletedKeys = @"deletedKeys";
NSString *BKiCloudContainerIdentifier;// MOVED to init @"iCloud.com.carloscabanero.blinkshell";
NSString *BKiCloudZoneName = @"DefaultZone";

static NSMutableDictionary *syncItems = nil;
static BKiCloudSyncHandler *sharedHandler = nil;

@interface BKiCloudSyncHandler ()
@property (nonatomic, strong) NSMutableArray *deletedHosts;
@property (nonatomic, strong) NSMutableArray *updatedHosts;
@property (nonatomic, strong) Reachability *internetReachable;
@end

@implementation BKiCloudSyncHandler

+ (instancetype)sharedHandler
{
  if ([BKUserConfigurationManager userSettingsValueForKey:BKUserConfigiCloud]) {
    if (sharedHandler == nil) {
      sharedHandler = [[self alloc] init];
    }
    return sharedHandler;
  } else {
    //If user settings is turned off, return nil, so that all messages are ignored
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    return nil;
  }
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    
    BKiCloudContainerIdentifier = [XCConfig infoPlistFullCloudID];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkForReachabilityAndSync:) name:kReachabilityChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkForReachabilityAndSync:) name:UIApplicationDidBecomeActiveNotification object:nil];
    _internetReachable = [Reachability reachabilityForInternetConnection];
    [_internetReachable startNotifier];
    [self loadSyncItems];
    CKDatabase *database = [[CKContainer containerWithIdentifier:BKiCloudContainerIdentifier] privateCloudDatabase];
    if (!database) {
      return nil;
    }
    CKRecordZone *zone = [[CKRecordZone alloc] initWithZoneName:BKiCloudZoneName];
    if (!zone) {
      return nil;
    }
    [database saveRecordZone:zone
	   completionHandler:^(CKRecordZone *_Nullable zone, NSError *_Nullable error) {
	     if (error) {
         NSLog(@"iCloud save record error: %@", error);
	       //Reset shared handler so that init is called again.
	     }
	   }];
    //If Query Subscription class is available ie. iOS 10+
    if ([CKQuerySubscription class]) {
      NSPredicate *predicate = [NSPredicate predicateWithValue:YES];
      CKQuerySubscription *subscripton = [[CKQuerySubscription alloc] initWithRecordType:@"BKHost" predicate:predicate options:(CKQuerySubscriptionOptionsFiresOnRecordCreation | CKQuerySubscriptionOptionsFiresOnRecordUpdate | CKQuerySubscriptionOptionsFiresOnRecordDeletion)];
      if (!subscripton) {
	return nil;
      }

      CKNotificationInfo *info = [[CKNotificationInfo alloc]init];
      info.shouldSendContentAvailable = YES;
      subscripton.notificationInfo = info;

      [database saveSubscription:subscripton
	       completionHandler:^(CKSubscription *_Nullable subscription, NSError *_Nullable error) {
		 if (error) {
       NSLog(@"iCloud Error: %@", error);
		   //Reset shared handler so that init is called again.
		 }
	       }];
    }
  }
  return self;
}

- (void)loadSyncItems
{
  // Load IDs from file
  if ((syncItems = [NSKeyedUnarchiver unarchiveObjectWithFile:[BlinkPaths blinkSyncItemsFile]]) == nil) {
    // Initialize the structure if it doesn't exist
    syncItems = [[NSMutableDictionary alloc] init];
  }
}

+ (BOOL)saveSyncItems
{
  return [NSKeyedArchiver archiveRootObject:syncItems toFile:[BlinkPaths blinkSyncItemsFile]];
}

- (void)checkForReachabilityAndSync:(NSNotification *)notification
{
  Reachability *reachability = [Reachability reachabilityForInternetConnection];
  [reachability startNotifier];
  NetworkStatus remoteHostStatus = [reachability currentReachabilityStatus];
  if (!(remoteHostStatus == NotReachable)) {
    [self syncFromiCloud];
  }
}

- (void)deleteAllItems
{
  NSMutableArray *deletedHosts = [NSMutableArray arrayWithArray:[syncItems objectForKey:BKiCloudSyncDeletedHosts]];
  for (CKRecordID *recordId in deletedHosts) {
    [self deleteRecord:recordId ofType:BKiCloudRecordTypeHosts];
  }
  [syncItems removeObjectForKey:BKiCloudSyncDeletedHosts];

  NSMutableArray *deletedKeys = [NSMutableArray arrayWithArray:[syncItems objectForKey:BKiCloudSyncDeletedKeys]];
  for (CKRecordID *recordId in deletedKeys) {
    [self deleteRecord:recordId ofType:BKiCloudRecordTypeKeys];
  }
  [syncItems removeObjectForKey:BKiCloudSyncDeletedKeys];
}

- (void)syncFromiCloud
{
  [self deleteAllItems];
  CKDatabase *database = [[CKContainer containerWithIdentifier:BKiCloudContainerIdentifier] privateCloudDatabase];
  CKQuery *hostQuery = [[CKQuery alloc] initWithRecordType:@"BKHost" predicate:[NSPredicate predicateWithValue:YES]];
  [database performQuery:hostQuery
            inZoneWithID:nil
       completionHandler:^(NSArray<CKRecord *> *_Nullable results, NSError *_Nullable error) {
         if (error) {
           NSLog(@"Error fetching hosts from icloud: %@", error);
           return;
         }
         [self mergeHosts:results];
       }];

  if ([BKUserConfigurationManager userSettingsValueForKey:BKUserConfigiCloudKeys]) {
    CKQuery *pubKeyQuery = [[CKQuery alloc] initWithRecordType:@"BKPubKey" predicate:[NSPredicate predicateWithValue:YES]];
    [database performQuery:pubKeyQuery
              inZoneWithID:nil
         completionHandler:^(NSArray<CKRecord *> *_Nullable results, NSError *_Nullable error) {
           if (error) {
             NSLog(@"Error fetching pubkeys from icloud: %@", error);
             return;
           }
	 }];
  }
}

- (void)deleteRecord:(CKRecordID *)recordId ofType:(BKiCloudRecordType)recordType
{
  NSString const *key = nil;
  if (recordType == BKiCloudRecordTypeHosts) {
    key = BKiCloudSyncDeletedHosts;
  } else {
    key = BKiCloudSyncDeletedKeys;
  }
  CKDatabase *database = [[CKContainer containerWithIdentifier:BKiCloudContainerIdentifier] privateCloudDatabase];
  [database deleteRecordWithID:recordId
	     completionHandler:^(CKRecordID *_Nullable recordID, NSError *_Nullable error) {
	       if (error) {
		 NSMutableArray *deletedItems = [NSMutableArray array];
		 if ([syncItems objectForKey:key]) {
		   deletedItems = [NSMutableArray arrayWithArray:[syncItems objectForKey:key]];
		 }
		 [deletedItems addObject:recordId];
		 [syncItems setObject:deletedItems forKey:key];
	       }
	     }];
}

#pragma mark - Host Methods

- (void)createNewHost:(BKHosts *)host
{
  CKDatabase *database = [[CKContainer containerWithIdentifier:BKiCloudContainerIdentifier] privateCloudDatabase];
  CKRecord *hostRecord = [BKHosts recordFromHost:host];
  [database saveRecord:hostRecord
     completionHandler:^(CKRecord *_Nullable record, NSError *_Nullable error) {
       [BKHosts updateHost:host.host withiCloudId:record.recordID andLastModifiedTime:record.modificationDate];
     }];
}


- (void)mergeHosts:(NSArray *)hostRecords
{
  for (CKRecord *hostRecord in hostRecords) {
    if ([hostRecord valueForKey:@"host"]) {
      NSString *host = [hostRecord valueForKey:@"host"];
      BKHosts *hosts = [BKHosts withiCloudId:hostRecord.recordID];
      //If host exists in system, Find which is new
      if (hosts) {
        if ([hosts.lastModifiedTime compare:hostRecord.modificationDate] == NSOrderedDescending) {
          //Local is new...Update iCloud to Local values
          CKDatabase *database = [[CKContainer containerWithIdentifier:BKiCloudContainerIdentifier] privateCloudDatabase];
          CKRecord *udpatedRecord = [BKHosts recordFromHost:hosts];
          CKModifyRecordsOperation *updateOperation = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:@[ udpatedRecord ] recordIDsToDelete:nil];
          updateOperation.savePolicy = CKRecordSaveAllKeys;
          updateOperation.qualityOfService = NSQualityOfServiceUserInitiated;
          updateOperation.modifyRecordsCompletionBlock = ^(NSArray<CKRecord *> *_Nullable savedRecords, NSArray<CKRecordID *> *_Nullable deletedRecordIDs, NSError *_Nullable operationError) {


          };
          [database addOperation:updateOperation];
        } else {
          //iCloud is new, update local to reflect iCLoud values
          [self saveHostRecord:hostRecord withHost:host];
        }
      } else {
        //If hosts is new, see if it exists
        //Check if name exists, if YES, Mark as conflict else, add to local
        BKHosts *existingHost = [BKHosts withHost:host];
        if (existingHost) {
          [BKHosts markHost:host forRecord:hostRecord withConflict:YES];
        } else {
          [self saveHostRecord:hostRecord withHost:host];
        }
      }
    }
  }
  NSMutableArray *itemsDeletedFromiCloud = [NSMutableArray array];
  //Save all local records to iCloud
  for (BKHosts *hosts in [BKHosts all]) {
    if (hosts.iCloudRecordId == nil && (!hosts.iCloudConflictDetected || !hosts.iCloudConflictDetected.boolValue)) {
      [self createNewHost:hosts];
    } else {
      NSLog(@"Conflict detected Hence not saving to iCloud");
      //Find items deleted from iCloud
      if ((!hosts.iCloudConflictDetected || !hosts.iCloudConflictDetected.boolValue)) {
        NSPredicate *deletedPredicate = [NSPredicate predicateWithFormat:@"SELF.recordID.recordName contains %@", hosts.iCloudRecordId.recordName];
        NSArray *filteredAray = [hostRecords filteredArrayUsingPredicate:deletedPredicate];
        if (filteredAray.count <= 0) {
          [itemsDeletedFromiCloud addObject:hosts];
        }
      }
    }
  }
  if (itemsDeletedFromiCloud.count > 0) {
    [[BKHosts all] removeObjectsInArray:itemsDeletedFromiCloud];
  }


  if (_mergeHostCompletionBlock != nil) {
    _mergeHostCompletionBlock();
  }
}

- (void)saveHostRecord:(CKRecord *)hostRecord withHost:(NSString *)host
{
  BKHosts *updatedHost = [BKHosts hostFromRecord:hostRecord];
  BKHosts *oldHost = [BKHosts withiCloudId:hostRecord.recordID];
  if (![updatedHost.host isEqualToString:oldHost.host]) {
    [[BKHosts all] removeObject:oldHost];
  }
  NSNumber *moshPort = updatedHost.moshPort;
  NSNumber *moshPortEnd = updatedHost.moshPortEnd;
  
  NSString *moshPortRange = moshPort ? moshPort.stringValue : @"";
  if (moshPort && moshPortEnd) {
    moshPortRange = [NSString stringWithFormat:@"%@:%@", moshPortRange, moshPortEnd.stringValue];
  }
  
  [BKHosts saveHost:host
        withNewHost:updatedHost.host
           hostName:updatedHost.hostName
            sshPort:updatedHost.port ? updatedHost.port.stringValue : @""
               user:updatedHost.user
           password:updatedHost.password
            hostKey:updatedHost.key
         moshServer:updatedHost.moshServer
      moshPortRange:moshPortRange
         startUpCmd:updatedHost.moshStartup prediction:updatedHost.prediction.intValue
           proxyCmd:updatedHost.proxyCmd
          proxyJump:updatedHost.proxyJump
sshConfigAttachment:updatedHost.sshConfigAttachment
      fpDomainsJSON:updatedHost.fpDomainsJSON
   ];
  [BKHosts updateHost:updatedHost.host withiCloudId:hostRecord.recordID andLastModifiedTime:hostRecord.modificationDate];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
