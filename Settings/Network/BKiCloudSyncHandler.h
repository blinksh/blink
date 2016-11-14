//
//  BKiCloudSyncHandler.h
//  Blink
//
//  Created by Atul M on 10/11/16.
//  Copyright © 2016 Carlos Cabañero Projects SL. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BKiCloudSyncHandler : NSObject
+ (id)sharedManager;
- (void)fetchFromiCloud;
@end
