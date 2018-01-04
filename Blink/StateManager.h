//
//  StateManager.h
//  Blink
//
//  Created by Yury Korolev on 12/30/17.
//  Copyright © 2017 Carlos Cabañero Projects SL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SessionParameters.h"

@protocol SecureRestoration

@property NSString * sessionStateKey;
@property SessionParameters *sessionParameters;

@end

@interface StateManager : NSObject

- (void)snapshotState:(id<SecureRestoration>) object;
- (void)restoreState:(id<SecureRestoration>) object;

- (void)load;
- (void)save;
- (void)reset;

@end
