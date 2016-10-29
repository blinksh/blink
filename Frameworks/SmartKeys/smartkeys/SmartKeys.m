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


static NSArray *HelperKeys = nil;
static NSArray *ArrowKeys = nil;
static NSArray *FKeys = nil;
static NSArray *AlternateKeys = nil; // To hold Function Keys F1 - F12
static NSArray *CursorKeys = nil;
@implementation SmartKeys {
  NSTimer *_timer;
}

@dynamic view;

+ (void)initialize {
  // Make an object. Do not even there to use dicts
  HelperKeys = @[
		    [[SmartKey alloc] initWithName:KbdTabKey symbol:@"\t"],
		    [[SmartKey alloc] initWithName:@"-" symbol:@"-"],
		    [[SmartKey alloc] initWithName:@"_" symbol:@"_"],
		    [[SmartKey alloc] initWithName:@"~" symbol:@"~"],
		    [[SmartKey alloc] initWithName:@"@" symbol:@"@"],
		    [[SmartKey alloc] initWithName:@"*" symbol:@"*"],
            [[SmartKey alloc] initWithName:@"|" symbol:@"|"],
            [[SmartKey alloc] initWithName:@"/" symbol:@"/"],
            [[SmartKey alloc] initWithName:@"\\" symbol:@"\\"],
            [[SmartKey alloc] initWithName:@"^" symbol:@"^"],
            [[SmartKey alloc] initWithName:@"[" symbol:@"["],
            [[SmartKey alloc] initWithName:@"]" symbol:@"]"],
            [[SmartKey alloc] initWithName:@"{" symbol:@"{"],
            [[SmartKey alloc] initWithName:@"}" symbol:@"}"]
		 ];
  
  ArrowKeys = @[
		[[SmartKey alloc]initWithName:KbdUpArrowKey symbol:UIKeyInputUpArrow],
		   [[SmartKey alloc]initWithName:KbdDownArrowKey symbol:UIKeyInputDownArrow],
		   [[SmartKey alloc]initWithName:KbdLeftArrowKey symbol:UIKeyInputLeftArrow],
		   [[SmartKey alloc]initWithName:KbdRightArrowKey symbol:UIKeyInputRightArrow]
		];
    
  AlternateKeys = @[
          [[SmartKey alloc]initWithName:@"F1" symbol:@"F1"],
          [[SmartKey alloc]initWithName:@"F2" symbol:@"F2"],
          [[SmartKey alloc]initWithName:@"F3" symbol:@"F3"],
          [[SmartKey alloc]initWithName:@"F4" symbol:@"F4"],
          [[SmartKey alloc]initWithName:@"F5" symbol:@"F5"],
          [[SmartKey alloc]initWithName:@"F6" symbol:@"F6"],
          [[SmartKey alloc]initWithName:@"F7" symbol:@"F7"],
          [[SmartKey alloc]initWithName:@"F8" symbol:@"F8"],
          [[SmartKey alloc]initWithName:@"F9" symbol:@"F9"],
          [[SmartKey alloc]initWithName:@"F10" symbol:@"F10"],
          [[SmartKey alloc]initWithName:@"F11" symbol:@"F11"],
          [[SmartKey alloc]initWithName:@"F12" symbol:@"F12"],
          ];
    
  CursorKeys = @[
         [[SmartKey alloc]initWithName:@"⇞" symbol:@"Pg Up"],
         [[SmartKey alloc]initWithName:@"⇟" symbol:@"Pg Down"],
         [[SmartKey alloc]initWithName:@"↖︎" symbol:@"Home"],
         [[SmartKey alloc]initWithName:@"↘︎" symbol:@"End"],
         ];
}

- (void)viewDidLoad 
{
    [self.view setNonModifiers:HelperKeys];
    [self.view setAlternateKeys:AlternateKeys];
    [self.view showNonModifierKeySection:SKNonModifierButtonTypeNormal];
    self.view.delegate = self;
}

- (void)symbolUp:(NSString *)symbol
{
  if (_timer != nil) {
    [_timer invalidate];
  }
}

- (void)symbolDown:(NSString *)symbol
{
    NSMutableArray *masterArray = [NSMutableArray array];
    [masterArray addObjectsFromArray:HelperKeys];
    [masterArray addObjectsFromArray:ArrowKeys];
    [masterArray addObjectsFromArray:AlternateKeys];
    [masterArray addObjectsFromArray:CursorKeys];
    
  for (SmartKey *key in masterArray) {
    if ([key.name isEqualToString:symbol]) {
      _timer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(symbolEmit:) userInfo:key.symbol repeats:YES];
      [_timer fire];
      return;
    }
  }
    //Handling Esc key separately as it does not logically belong to either of the above arrays
    if ([KbdEscKey isEqualToString:symbol]) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(symbolEmit:) userInfo:UIKeyInputEscape repeats:YES];
        [_timer fire];
    }
}

- (void)symbolEmit:(NSTimer *)timer
{
  [_textInputDelegate insertText:timer.userInfo];
}

@end
