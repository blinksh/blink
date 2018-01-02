//
//  MCPSessionParameters.m
//  Blink
//
//  Created by Yury Korolev on 1/2/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import "MCPSessionParameters.h"

NSString * const ChildSessionTypeKey = @"childSessionType";
NSString * const ChildSessionParametersKey = @"childSessionParameters";
NSString * const RowsKey = @"rows";
NSString * const ColsKey = @"cols";

@implementation MCPSessionParameters

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
  self = [super initWithCoder:aDecoder];
  
  if (self) {
    self.childSessionType = [aDecoder decodeObjectForKey:ChildSessionTypeKey];
    self.childSessionParameters = [aDecoder decodeObjectForKey:ChildSessionParametersKey];
    self.rows = [aDecoder decodeIntegerForKey:RowsKey];
    self.cols = [aDecoder decodeIntegerForKey:ColsKey];
  }
  
  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
  [super encodeWithCoder:coder];
  [coder encodeObject:_childSessionType forKey:ChildSessionTypeKey];
  [coder encodeObject:_childSessionParameters forKey:ChildSessionParametersKey];
  [coder encodeInteger:_rows forKey:RowsKey];
  [coder encodeInteger:_cols forKey:ColsKey];
}

@end

