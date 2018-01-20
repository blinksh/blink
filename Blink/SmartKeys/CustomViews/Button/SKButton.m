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

#import "SKButton.h"

@implementation SKButton
@synthesize backgroundLayer;

// Remove underline. See https://github.com/blinksh/blink/issues/73
// For buttons from StoryBoard
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
  self = [super initWithCoder:aDecoder];
  if (self) {
    [self setBackgroundImage:[[UIImage alloc] init] forState:UIControlStateNormal];
  }
  return self;
}

// For other SKButtons
- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    [self setBackgroundImage:[[UIImage alloc] init] forState:UIControlStateNormal];
  }
  return self;
}

- (void)animatedButtonSelection:(BOOL)selected
{
  if (selected) {
    if (self.backgroundLayer != nil) {
      [self.backgroundLayer removeFromSuperlayer];
    }
    self.backgroundLayer = [[CALayer alloc] init];
    self.backgroundLayer.cornerRadius = 5;
    self.backgroundLayer.frame = CGRectMake(2, 2, self.frame.size.width - 4, self.frame.size.height - 4);
    self.backgroundLayer.backgroundColor = [UIColor colorWithRed:86.0 / 255.0 green:234.0 / 255.0 blue:241.0 / 255.0 alpha:1.0].CGColor;

    CABasicAnimation *theAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    theAnimation.duration = 0.2;
    theAnimation.fromValue = [NSNumber numberWithFloat:0.0];
    theAnimation.toValue = [NSNumber numberWithFloat:1.0];
    [self.backgroundLayer addAnimation:theAnimation forKey:@"animateOpacity"];

    [self.layer insertSublayer:self.backgroundLayer atIndex:0];
  } else {
    self.backgroundLayer.opacity = 0.0;

    [CATransaction begin];
    CABasicAnimation *theAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    theAnimation.duration = 0.2;
    theAnimation.fromValue = [NSNumber numberWithFloat:1.0];
    theAnimation.toValue = [NSNumber numberWithFloat:0.0];
    [CATransaction setCompletionBlock:^{
      if (self.backgroundLayer != nil) {
        [self.backgroundLayer removeFromSuperlayer];
      }
    }];
    [self.backgroundLayer addAnimation:theAnimation forKey:@"animateOpacity"];
    [CATransaction commit];
  }
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  self.backgroundLayer.frame = CGRectMake(2, 2, self.frame.size.width - 4, self.frame.size.height - 4);
}
@end
