//
//  BKiCloudSyncHandler.h
//  Blink
//
//  Created by Atul M on 10/11/16.
//  Copyright © 2016 Carlos Cabañero Projects SL. All rights reserved.
//

#import <Foundation/Foundation.h>
@class BKHosts;
@class CKRecordID;

typedef enum{
  BKiCloudRecordTypeHosts,
  BKiCloudRecordTypeKeys
}BKiCloudRecordType;

extern NSString const *BKiCloudSyncDeletedHosts;
extern NSString const *BKiCloudSyncUpdatedHosts;

@interface BKiCloudSyncHandler : NSObject
+ (id)sharedHandler;
- (void)fetchFromiCloud;
- (void)deleteRecord:(CKRecordID*)recordId ofType:(BKiCloudRecordType)recordType;

- (void)createNewHost:(BKHosts*)host;

@end
