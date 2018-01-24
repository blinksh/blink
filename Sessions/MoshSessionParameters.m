////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016 Blink Mobile Shell Project
//
// This file is part of Blink.
//
// Blink is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Blink is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Blink. If not, see <http://www.gnu.org/licenses/>.
//
// In addition, Blink is also subject to certain additional terms under
// GNU GPL version 3 section 7.
//
// You should have received a copy of these additional terms immediately
// following the terms and conditions of the GNU General Public License
// which accompanied the Blink Source Code. If not, see
// <http://www.github.com/blinksh/blink>.
//
////////////////////////////////////////////////////////////////////////////////

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
