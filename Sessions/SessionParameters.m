//
//  SessionParameters.m
//  Blink
//
//  Created by Yury Korolev on 1/2/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import "SessionParameters.h"

NSString * const EncodedStateKey = @"EncodedStateKey";

@implementation SessionParameters

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super init];
  if (self) {
    self.encodedState = [aDecoder decodeObjectForKey:EncodedStateKey];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder{
  [aCoder encodeObject:_encodedState forKey:EncodedStateKey];
}

@end
