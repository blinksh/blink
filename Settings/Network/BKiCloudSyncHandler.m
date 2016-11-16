//
//  BKiCloudSyncHandler.m
//  Blink
//
//  Created by Atul M on 10/11/16.
//  Copyright © 2016 Carlos Cabañero Projects SL. All rights reserved.
//

#import "BKiCloudSyncHandler.h"
#import "BKHosts.h"
#import "Reachability.h"
@import CloudKit;

NSString const *BKiCloudSyncDeletedHosts = @"deletedHosts";
NSString const *BKiCloudSyncUpdatedHosts = @"updatedHosts";

static NSURL *DocumentsDirectory = nil;
static NSURL *syncItemsURL = nil;
static NSMutableDictionary *syncItems = nil;

@interface BKiCloudSyncHandler ()
@property (nonatomic, strong) NSMutableArray *deletedHosts;
@property (nonatomic, strong) NSMutableArray *updatedHosts;
@end

@implementation BKiCloudSyncHandler

+ (id)sharedHandler{
  static BKiCloudSyncHandler *sharedHandler = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedHandler = [[self alloc] init];
  });
  return sharedHandler;
}

+ (void)loadSyncItems
{
  if (DocumentsDirectory == nil) {
    DocumentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    syncItemsURL = [DocumentsDirectory URLByAppendingPathComponent:@"syncItems"];
  }
  // Load IDs from file
  if ((syncItems = [NSKeyedUnarchiver unarchiveObjectWithFile:syncItemsURL.path]) == nil) {
    // Initialize the structure if it doesn't exist
    syncItems = [[NSMutableDictionary alloc] init];
  }
}

+ (void)initialize{
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkForReachability) name:kReachabilityChangedNotification object:nil];
  [self loadSyncItems];
}

+ (BOOL)saveSyncItems{
    return [NSKeyedArchiver archiveRootObject:syncItems toFile:syncItemsURL.path];
}

- (void)checkForReachability{
  Reachability *reachability = [Reachability reachabilityForInternetConnection];
  [reachability startNotifier];
  NetworkStatus remoteHostStatus = [reachability currentReachabilityStatus];
  if(remoteHostStatus == NotReachable) {

  }else{
    [self deleteAllItems];
    [self fetchFromiCloud];
  }
}

- (void)deleteAllItems{
  NSMutableArray *deletedHosts = [NSMutableArray arrayWithArray:[syncItems objectForKey:BKiCloudSyncDeletedHosts]];
  for (CKRecordID *recordId in deletedHosts) {
    [self deleteHostWithId:recordId];
  }
  [syncItems removeObjectForKey:BKiCloudSyncDeletedHosts];
}

- (void)fetchFromiCloud{
  CKDatabase *database = [[CKContainer containerWithIdentifier:@"iCloud.com.carloscabanero.blinkshell"]privateCloudDatabase];
  CKQuery *hostQuery = [[CKQuery alloc]initWithRecordType:@"BKHost" predicate:[NSPredicate predicateWithValue:YES]];
  [database performQuery:hostQuery inZoneWithID:nil completionHandler:^(NSArray<CKRecord *> * _Nullable results, NSError * _Nullable error) {
    [self mergeHosts:results];
  }];
  CKQuery *pubKeyQuery = [[CKQuery alloc]initWithRecordType:@"BKPubKey" predicate:[NSPredicate predicateWithValue:YES]];
  [database performQuery:pubKeyQuery inZoneWithID:nil completionHandler:^(NSArray<CKRecord *> * _Nullable results, NSError * _Nullable error) {
    [self mergeKeys:results];
  }];
}

- (void)createNewHost:(BKHosts*)host{
  CKDatabase *database = [[CKContainer containerWithIdentifier:@"iCloud.com.carloscabanero.blinkshell"]privateCloudDatabase];
  CKRecord *hostRecord = [BKHosts recordFromHost:host];
  [database saveRecord:hostRecord completionHandler:^(CKRecord * _Nullable record, NSError * _Nullable error) {
    [BKHosts saveHost:host.host withiCloudId:record.recordID andLastModifiedTime:record.modificationDate];
  }];
}


- (void)mergeHosts:(NSArray*)hostRecords{
  for (CKRecord *hostRecord in hostRecords) {
    if([hostRecord valueForKey:@"host"]){
      NSString *host = [hostRecord valueForKey:@"host"];
      BKHosts *hosts = [BKHosts withiCloudId:hostRecord.recordID];
      //If host exists in system, Find which is new
      if(hosts){
        if([hosts.lastModifiedTime compare:hostRecord.modificationDate] == NSOrderedDescending){
          //Local is new...Update iCloud to Local values
          CKDatabase *database = [[CKContainer containerWithIdentifier:@"iCloud.com.carloscabanero.blinkshell"]privateCloudDatabase];
          CKRecord *udpatedRecord = [BKHosts recordFromHost:hosts];
          CKModifyRecordsOperation *updateOperation = [[CKModifyRecordsOperation alloc]initWithRecordsToSave:@[udpatedRecord] recordIDsToDelete:nil];
          updateOperation.savePolicy = CKRecordSaveAllKeys;
          updateOperation.qualityOfService = NSQualityOfServiceUserInitiated;
          updateOperation.modifyRecordsCompletionBlock = ^(NSArray<CKRecord *> * _Nullable savedRecords, NSArray<CKRecordID *> * _Nullable deletedRecordIDs, NSError * _Nullable operationError){
            
            
          };
          [database addOperation:updateOperation];
        }else{
          //iCloud is new, update local to reflect iCLoud values
          [self saveHostRecord:hostRecord withHost:host];
        }
      }else{
        //If hosts is new, see if it exists
        //Check if name exists, if YES, Mark as conflict else, add to local
        BKHosts *existingHost = [BKHosts withHost:host];
        if(existingHost){
          [BKHosts markHost:host withConflict:YES];
        }else{
          [self saveHostRecord:hostRecord withHost:host];
        }
      }
    }
  }
  //Save all local records to iCloud
  for (BKHosts *hosts in [BKHosts all]) {
    if(hosts.iCloudRecordId == nil && !hosts.iCloudConflictDetected){
      [self createNewHost:hosts];
    }else{
      NSLog(@"Conflict detected Hence not saving to iCloud");
    }
  }
}

- (void)saveHostRecord:(CKRecord*)hostRecord withHost:(NSString*)host{
  BKHosts *updatedHost = [BKHosts hostFromRecord:hostRecord];
  [BKHosts saveHost:host withNewHost:updatedHost.host hostName:updatedHost.hostName sshPort:updatedHost.port.stringValue user:updatedHost.user password:updatedHost.password hostKey:updatedHost.key moshServer:updatedHost.moshServer moshPort:updatedHost.moshPort.stringValue startUpCmd:updatedHost.moshStartup prediction:updatedHost.prediction.intValue];
  [BKHosts saveHost:updatedHost.host withiCloudId:hostRecord.recordID andLastModifiedTime:hostRecord.modificationDate];

}

- (void)deleteHostWithId:(CKRecordID*)recordId{
  CKDatabase *database = [[CKContainer containerWithIdentifier:@"iCloud.com.carloscabanero.blinkshell"]privateCloudDatabase];
  [database deleteRecordWithID:recordId completionHandler:^(CKRecordID * _Nullable recordID, NSError * _Nullable error) {
    if(error){
      NSMutableArray *deletedHosts = [NSMutableArray array];
      if([syncItems objectForKey:BKiCloudSyncDeletedHosts]){
        deletedHosts = [NSMutableArray arrayWithArray:[syncItems objectForKey:BKiCloudSyncDeletedHosts]];
      }
      [deletedHosts addObject:recordId];
      [syncItems setObject:deletedHosts forKey:BKiCloudSyncDeletedHosts];
    }
  }];
}

- (void)mergeKeys:(NSArray*)keys{
  
}
@end
