//
//  MoshSessionParameters.m
//  Blink
//
//  Created by Yury Korolev on 1/2/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import "MoshSessionParameters.h"

NSString * const IPKey = @"ip";
NSString * const PortKey = @"port";
NSString * const KeyKey = @"key";
NSString * const PredictionModeKey = @"predictionMode";
NSString * const StartupCmdKey = @"startupCmd";
NSString * const ServerPathKey = @"serverPath";

@implementation MoshParameters

- (instancetype)initWithCoder:(NSCoder *)aDecoder{
  self = [super initWithCoder:aDecoder];
  
  if (self) {
    self.ip = [aDecoder decodeObjectForKey:IPKey];
    self.port = [aDecoder decodeObjectForKey:PortKey];
    self.key = [aDecoder decodeObjectForKey:KeyKey];
    self.predictionMode = [aDecoder decodeObjectForKey:PredictionModeKey];
    self.startupCmd = [aDecoder decodeObjectForKey:StartupCmdKey];
    self.serverPath = [aDecoder decodeObjectForKey:ServerPathKey];
  }
  
  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
  [super encodeWithCoder:coder];
  
  [coder encodeObject:_ip forKey:IPKey];
  [coder encodeObject:_port forKey:PortKey];
  [coder encodeObject:_key forKey:KeyKey];
  [coder encodeObject:_predictionMode forKey:PredictionModeKey];
  [coder encodeObject:_startupCmd forKey:StartupCmdKey];
  [coder encodeObject:_serverPath forKey:ServerPathKey];
}
@end
