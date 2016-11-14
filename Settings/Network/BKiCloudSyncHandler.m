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
  CKRecord *hostRecord = [[CKRecord alloc]initWithRecordType:@"BKHost"];
  [hostRecord setValue:host.host forKey:@"host"];
  [hostRecord setValue:host.hostName forKey:@"hostName"];
  [hostRecord setValue:host.key forKey:@"key"];
  [hostRecord setValue:host.moshPort forKey:@"moshPort"];
  [hostRecord setValue:host.moshServer forKey:@"moshServer"];
  [hostRecord setValue:host.moshStartup forKey:@"moshStartup"];
  [hostRecord setValue:host.password forKey:@"password"];
  [hostRecord setValue:host.passwordRef forKey:@"passwordRef"];
  [hostRecord setValue:host.port forKey:@"port"];
  [hostRecord setValue:host.prediction forKey:@"prediction"];
  [hostRecord setValue:host.user forKey:@"user"];

  [database saveRecord:hostRecord completionHandler:^(CKRecord * _Nullable record, NSError * _Nullable error) {
    [BKHosts saveHost:host.host withiCloudId:record.recordID andLastModifiedTime:record.modificationDate];
  }];
}

- (void)mergeHosts:(NSArray*)hosts{
  
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
