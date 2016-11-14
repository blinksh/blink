//
//  BKiCloudSyncHandler.m
//  Blink
//
//  Created by Atul M on 10/11/16.
//  Copyright © 2016 Carlos Cabañero Projects SL. All rights reserved.
//

#import "BKiCloudSyncHandler.h"
#import "Reachability.h"
@import CloudKit;

@implementation BKiCloudSyncHandler

+ (id)sharedHandler{
  static BKiCloudSyncHandler *sharedHandler = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedHandler = [[self alloc] init];
  });
  return sharedHandler;
}

+ (void)initialize{
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkForReachability) name:kReachabilityChangedNotification object:nil];
}

- (void)checkForReachability{
  Reachability *reachability = [Reachability reachabilityForInternetConnection];
  [reachability startNotifier];
  NetworkStatus remoteHostStatus = [reachability currentReachabilityStatus];
  if(remoteHostStatus == NotReachable) {

  }else{
    
  }
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

- (void)mergeHosts:(NSArray*)hosts{
  
}

- (void)mergeKeys:(NSArray*)keys{
  
}
@end
