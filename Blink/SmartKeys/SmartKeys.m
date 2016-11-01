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

#import "SmartKeys.h"


NSString *const SpecialCursorKeyHome = @"SpecialCursorKeyHome";
NSString *const SpecialCursorKeyEnd = @"SpecialCursorKeyEnd";
NSString *const SpecialCursorKeyPgUp = @"SpecialCursorKeyPgUp";
NSString *const SpecialCursorKeyPgDown = @"SpecialCursorKeyPgDown";

static NSArray *HelperKeys = nil;
static NSArray *ArrowKeys = nil;
static NSArray *FKeys = nil;
static NSArray *AlternateKeys = nil; // To hold Function Keys F1 - F12
static NSArray *CursorKeys = nil;


@interface SmartKeys ()

@property NSMutableArray *allKeys;

@end

@implementation SmartKeys {
  NSTimer *_timer;
}

@dynamic view;

+ (void)initialize
{
  // Make an object. Do not even there to use dicts
  HelperKeys = @[
    [[SmartKey alloc] initWithName:KbdTabKey
                            symbol:@"\t"],
    [[SmartKey alloc] initWithName:@"-"
                            symbol:@"-"],
    [[SmartKey alloc] initWithName:@"_"
                            symbol:@"_"],
    [[SmartKey alloc] initWithName:@"~"
                            symbol:@"~"],
    [[SmartKey alloc] initWithName:@"@"
                            symbol:@"@"],
    [[SmartKey alloc] initWithName:@"*"
                            symbol:@"*"],
    [[SmartKey alloc] initWithName:@"|"
                            symbol:@"|"],
    [[SmartKey alloc] initWithName:@"/"
                            symbol:@"/"],
    [[SmartKey alloc] initWithName:@"\\"
                            symbol:@"\\"],
    [[SmartKey alloc] initWithName:@"^"
                            symbol:@"^"],
    [[SmartKey alloc] initWithName:@"["
                            symbol:@"["],
    [[SmartKey alloc] initWithName:@"]"
                            symbol:@"]"],
    [[SmartKey alloc] initWithName:@"{"
                            symbol:@"{"],
    [[SmartKey alloc] initWithName:@"}"
                            symbol:@"}"]
  ];

  ArrowKeys = @[
    [[SmartKey alloc] initWithName:KbdUpArrowKey
                            symbol:UIKeyInputUpArrow],
    [[SmartKey alloc] initWithName:KbdDownArrowKey
                            symbol:UIKeyInputDownArrow],
    [[SmartKey alloc] initWithName:KbdLeftArrowKey
                            symbol:UIKeyInputLeftArrow],
    [[SmartKey alloc] initWithName:KbdRightArrowKey
                            symbol:UIKeyInputRightArrow]
  ];

  AlternateKeys = @[
    [[SmartKey alloc] initWithName:@"F1"
                            symbol:@"FKEY1"],
    [[SmartKey alloc] initWithName:@"F2"
                            symbol:@"FKEY2"],
    [[SmartKey alloc] initWithName:@"F3"
                            symbol:@"FKEY3"],
    [[SmartKey alloc] initWithName:@"F4"
                            symbol:@"FKEY4"],
    [[SmartKey alloc] initWithName:@"F5"
                            symbol:@"FKEY5"],
    [[SmartKey alloc] initWithName:@"F6"
                            symbol:@"FKEY6"],
    [[SmartKey alloc] initWithName:@"F7"
                            symbol:@"FKEY7"],
    [[SmartKey alloc] initWithName:@"F8"
                            symbol:@"FKEY8"],
    [[SmartKey alloc] initWithName:@"F9"
                            symbol:@"FKEY9"],
    [[SmartKey alloc] initWithName:@"F10"
                            symbol:@"FKEY10"],
    [[SmartKey alloc] initWithName:@"F11"
                            symbol:@"FKEY11"],
    [[SmartKey alloc] initWithName:@"F12"
                            symbol:@"FKEY12"],
  ];

  CursorKeys = @[
    [[SmartKey alloc] initWithName:KbdPageUpKey
                            symbol:SpecialCursorKeyPgUp],
    [[SmartKey alloc] initWithName:KbdPageDownKey
                            symbol:SpecialCursorKeyPgDown],
    [[SmartKey alloc] initWithName:KbdHomeKey
                            symbol:SpecialCursorKeyHome],
    [[SmartKey alloc] initWithName:KbdEndKey
                            symbol:SpecialCursorKeyEnd],
  ];
}

- (void)viewDidLoad
{
  [self.view setNonModifiers:HelperKeys];
  [self.view setAlternateKeys:AlternateKeys];
  [self.view showNonModifierKeySection:SKNonModifierButtonTypeNormal];
  self.view.delegate = self;

  self.allKeys = [NSMutableArray array];
  [self.allKeys addObjectsFromArray:HelperKeys];
  [self.allKeys addObjectsFromArray:ArrowKeys];
  [self.allKeys addObjectsFromArray:AlternateKeys];
  [self.allKeys addObjectsFromArray:CursorKeys];
  [self.allKeys addObject:[[SmartKey alloc] initWithName:KbdEscKey symbol:UIKeyInputEscape]];
}

- (void)symbolUp:(NSString *)symbol
{
  if (_timer != nil) {
    [_timer invalidate];
    _timer = nil;
  }
}

- (void)symbolDown:(NSString *)symbol
{
  for (SmartKey *key in self.allKeys) {
    if ([key.name isEqualToString:symbol]) {
      [_textInputDelegate insertText:key.symbol];
      _timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(symbolEmit:) userInfo:key.symbol repeats:YES];
      //[_timer fire];
      return;
    }
  }
}

- (void)symbolEmit:(NSTimer *)timer
{
  [_textInputDelegate insertText:timer.userInfo];

  if ([_timer isValid]) {
    _timer.fireDate = [NSDate dateWithTimeIntervalSinceNow:0.1];
  }
}

- (void)nonModifierKeysSwitched
{
  if (_timer != nil) {
    [_timer invalidate];
    _timer = nil;
  }
}

@end
