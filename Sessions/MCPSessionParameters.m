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

#import "MCPSessionParameters.h"
#import "MoshSessionParameters.h"
#import "SessionParameters.h"

NSString * const ChildSessionTypeKey = @"childSessionType";
NSString * const ChildSessionParametersKey = @"childSessionParameters";
NSString * const RowsKey = @"rows";
NSString * const ColsKey = @"cols";
NSString * const FontSizeKey = @"fontSize";
NSString * const FontNameKey = @"fontName";
NSString * const ThemeNameKey = @"themeName";
NSString * const EnableBoldKey = @"enableBold";
NSString * const BoldAsBrightKey = @"boldAsBright";

@implementation MCPSessionParameters

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
  self = [super initWithCoder:aDecoder];
  
  if (self) {
    NSSet *classes = [NSSet setWithObjects:[MoshParameters class], [SessionParameters class], nil];
    self.childSessionType = [aDecoder decodeObjectOfClass:[NSString class] forKey:ChildSessionTypeKey];
    self.childSessionParameters = [aDecoder decodeObjectOfClasses:classes forKey:ChildSessionParametersKey];
    self.rows = [aDecoder decodeIntegerForKey:RowsKey];
    self.cols = [aDecoder decodeIntegerForKey:ColsKey];
    self.fontSize = [aDecoder decodeIntegerForKey:FontSizeKey];
    self.fontName = [aDecoder decodeObjectOfClass:[NSString class] forKey:FontNameKey];
    self.themeName = [aDecoder decodeObjectOfClass:[NSString class] forKey:ThemeNameKey];
    self.enableBold = [aDecoder decodeIntegerForKey:EnableBoldKey];
    self.boldAsBright = [aDecoder decodeBoolForKey:BoldAsBrightKey];
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
  [coder encodeInteger:_fontSize forKey:FontSizeKey];
  [coder encodeObject:_fontName forKey:FontNameKey];
  [coder encodeObject:_themeName forKey:ThemeNameKey];
  [coder encodeInteger:_enableBold forKey:EnableBoldKey];
  [coder encodeBool:_boldAsBright forKey:BoldAsBrightKey];
}

+ (BOOL)supportsSecureCoding
{
  return YES;
}

- (BOOL)hasEncodedState
{
  return _childSessionParameters.encodedState;
}

- (void)cleanEncodedState
{
  [_childSessionParameters cleanEncodedState];
  [super cleanEncodedState];
}

@end

