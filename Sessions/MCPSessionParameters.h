//
//  MCPSessionParameters.h
//  Blink
//
//  Created by Yury Korolev on 1/2/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SessionParameters.h"

@interface MCPSessionParameters: SessionParameters
@property (strong) NSString *childSessionType;
@property (strong) SessionParameters *childSessionParameters;
@property NSInteger rows;
@property NSInteger cols;
@end

