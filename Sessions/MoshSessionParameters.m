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
    self.ip = [aDecoder decodeObjectOfClass:[NSString class] forKey:IPKey];
    self.port = [aDecoder decodeObjectOfClass:[NSString class] forKey:PortKey];
    self.key = [aDecoder decodeObjectOfClass:[NSString class] forKey:KeyKey];
    self.predictionMode = [aDecoder decodeObjectOfClass:[NSString class] forKey:PredictionModeKey];
    self.startupCmd = [aDecoder decodeObjectOfClass:[NSString class] forKey:StartupCmdKey];
    self.serverPath = [aDecoder decodeObjectOfClass:[NSString class] forKey:ServerPathKey];
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

+ (BOOL)supportsSecureCoding
{
  return YES;
}

@end
