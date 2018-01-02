//
//  SessionParameters.h
//  Blink
//
//  Created by Yury Korolev on 1/2/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SessionParameters: NSObject<NSCoding>
@property NSData *encodedState;
@end
