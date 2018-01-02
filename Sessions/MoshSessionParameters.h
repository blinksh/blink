//
//  MoshSessionParameters.h
//  Blink
//
//  Created by Yury Korolev on 1/2/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SessionParameters.h"

@interface MoshParameters: SessionParameters
@property (strong) NSString *ip;
@property (strong) NSString *port;
@property (strong) NSString *key;
@property (strong) NSString *predictionMode;
@property (strong) NSString *startupCmd;
@property (strong) NSString *serverPath;
@end
