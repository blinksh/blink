//
//  StateManager.h
//  Blink
//
//  Created by Yury Korolev on 12/30/17.
//  Copyright © 2017 Carlos Cabañero Projects SL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Session.h"

@interface StateManager : NSObject

+ (StateManager *)shared;

- (void)storeSessionParams:(NSString *)sessionKey params:(NSObject *)params;
- (void)removeSession:(NSString *)sessionKey;
- (NSObject *)restoreSessionParamsForKey:(NSString *)sessionKey;


@end
