//
//  BKiCloudSyncHandler.m
//  Blink
//
//  Created by Atul M on 10/11/16.
//  Copyright © 2016 Carlos Cabañero Projects SL. All rights reserved.
//

#import "BKiCloudSyncHandler.h"
#import "BKHosts.h"
#import "BKPubKey.h"
#import "Reachability.h"
@import CloudKit;



NSString const *BKiCloudSyncDeletedHosts = @"deletedHosts";
NSString const *BKiCloudSyncDeletedKeys = @"deletedKeys";

static NSURL *DocumentsDirectory = nil;
static NSURL *syncItemsURL = nil;
static NSMutableDictionary *syncItems = nil;
static BKiCloudSyncHandler *sharedHandler = nil;


@interface BKiCloudSyncHandler ()
@property (nonatomic, strong) NSMutableArray *deletedHosts;
@property (nonatomic, strong) NSMutableArray *updatedHosts;
@property (nonatomic, strong) Reachability *internetReachable;
@end

@implementation BKiCloudSyncHandler

+ (id)sharedHandler{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedHandler = [[self alloc] init];
  });
  return sharedHandler;
}

- (instancetype)init{
  self = [super init];
  if(self){
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkForReachability:) name:kReachabilityChangedNotification object:nil];
    _internetReachable = [Reachability reachabilityForInternetConnection];
    [_internetReachable startNotifier];
    [self loadSyncItems];
  }
  return self;
}

- (void)loadSyncItems
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

+ (BOOL)saveSyncItems{
    return [NSKeyedArchiver archiveRootObject:syncItems toFile:syncItemsURL.path];
}

- (void)checkForReachability:(NSNotification*)notification{
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
    [self deleteRecord:recordId ofType:BKiCloudRecordTypeHosts];
  }
  [syncItems removeObjectForKey:BKiCloudSyncDeletedHosts];
  
  NSMutableArray *deletedKeys = [NSMutableArray arrayWithArray:[syncItems objectForKey:BKiCloudSyncDeletedKeys]];
  for (CKRecordID *recordId in deletedKeys) {
    [self deleteRecord:recordId ofType:BKiCloudRecordTypeKeys];
  }
  [syncItems removeObjectForKey:BKiCloudSyncDeletedKeys];
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

- (void)deleteRecord:(CKRecordID*)recordId ofType:(BKiCloudRecordType)recordType{
  NSString const *key = nil;
  if(recordType == BKiCloudRecordTypeHosts){
    key = BKiCloudSyncDeletedHosts;
  }else{
    key = BKiCloudSyncDeletedKeys;
  }
  CKDatabase *database = [[CKContainer containerWithIdentifier:@"iCloud.com.carloscabanero.blinkshell"]privateCloudDatabase];
  [database deleteRecordWithID:recordId completionHandler:^(CKRecordID * _Nullable recordID, NSError * _Nullable error) {
    if(error){
      NSMutableArray *deletedItems = [NSMutableArray array];
      if([syncItems objectForKey:key]){
        deletedItems = [NSMutableArray arrayWithArray:[syncItems objectForKey:key]];
      }
      [deletedItems addObject:recordId];
      [syncItems setObject:deletedItems forKey:key];
    }
  }];
}

# pragma mark - Host Methods

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
          [BKHosts markHost:host forRecord:hostRecord withConflict:YES];
        }else{
          [self saveHostRecord:hostRecord withHost:host];
        }
      }
    }
  }
  //Save all local records to iCloud
  for (BKHosts *hosts in [BKHosts all]) {
    if(hosts.iCloudRecordId == nil && (!hosts.iCloudConflictDetected || hosts.iCloudConflictDetected == [NSNumber numberWithBool:NO])){
      [self createNewHost:hosts];
    }else{
      NSLog(@"Conflict detected Hence not saving to iCloud");
    }
  }
  if(_mergeHostCompletionBlock != nil){
    _mergeHostCompletionBlock();
  }
}

- (void)saveHostRecord:(CKRecord*)hostRecord withHost:(NSString*)host{
  BKHosts *updatedHost = [BKHosts hostFromRecord:hostRecord];
  [BKHosts saveHost:host withNewHost:updatedHost.host hostName:updatedHost.hostName sshPort:updatedHost.port.stringValue user:updatedHost.user password:updatedHost.password hostKey:updatedHost.key moshServer:updatedHost.moshServer moshPort:updatedHost.moshPort.stringValue startUpCmd:updatedHost.moshStartup prediction:updatedHost.prediction.intValue];
  [BKHosts saveHost:updatedHost.host withiCloudId:hostRecord.recordID andLastModifiedTime:hostRecord.modificationDate];
}

# pragma mark - Keys Method

- (void)mergeKeys:(NSArray*)keys{
  
}

//- (void)createNewKey:(BKPubKey*)key{
//  CKDatabase *database = [[CKContainer containerWithIdentifier:@"iCloud.com.carloscabanero.blinkshell"]privateCloudDatabase];
//  CKRecord *keyRecord = [BKPubKey recordFromHost:key];
//  [database saveRecord:hostRecord completionHandler:^(CKRecord * _Nullable record, NSError * _Nullable error) {
//    [BKHosts saveHost:host.host withiCloudId:record.recordID andLastModifiedTime:record.modificationDate];
//  }];
//}

@end
