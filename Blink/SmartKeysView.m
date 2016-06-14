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

#import "SmartKeysView.h"

NSString *const KbdLeftArrowKey = @"◀︎";
NSString *const KbdRightArrowKey = @"▶︎";
NSString *const KbdUpArrowKey = @"▲";
NSString *const KbdDownArrowKey = @"▼";
NSString *const KbdEscKey = @"esc";
NSString *const KbdTabKey = @"⇥";


@implementation SmartKeysView {
  NSTimer *_timer;
  __weak IBOutlet UIButton *_ctrlButton;
  __weak IBOutlet UIButton *_altButton;
  __weak IBOutlet UIStackView *_stack;
}

- (void)awakeFromNib
{
  self.translatesAutoresizingMaskIntoConstraints = NO;
}

- (NSUInteger)modifiers
{
  // No need to use the tag, as modifiers are predefined.
  NSUInteger modifiers = 0;
  if (_ctrlButton.highlighted) {
    modifiers |= KbdCtrlModifier;
  }
  if (_altButton.highlighted) {
    modifiers |= KbdAltModifier;
  }

  return modifiers;
}

- (void)show
{
  self.hidden = NO;
}
- (void)layoutSubviews
{
  if (UIDeviceOrientationIsPortrait([UIDevice currentDevice].orientation)) {
    //        _approxButton.hidden = YES;
    //        _HashButton.hidden = YES;
    //        _AtTheRateButton.hidden = YES;
    //        _DollarButton.hidden = YES;
  } else {

    //        _approxButton.hidden = NO;
    //        _HashButton.hidden = NO;
    //        _AtTheRateButton.hidden = NO;
    //        _DollarButton.hidden = NO;
  }
}

- (UIInputViewStyle)inputViewStyle
{
  return UIInputViewStyleDefault;
}

@end
