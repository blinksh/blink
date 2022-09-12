////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2018 Blink Mobile Shell Project
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

#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import <objc/runtime.h>

BOOL switched = NO;

@interface TestApp : UIApplication

@end

@implementation TestApp

+ (void)initialize {
  NSString * clsName = [@[
      @"UIKeyboardImpl"
  ] componentsJoinedByString:@""];

  Class cls = NSClassFromString(clsName);

  SEL selector = sel_getUid("canPresentPressAndHoldPopover:");
  Method method = class_getInstanceMethod(cls, selector);
//  IMP original = method_getImplementation(method);
  IMP override = imp_implementationWithBlock(^BOOL(id me, void* arg0) {
    return NO;
  });
  method_setImplementation(method, override);
}

//- (void)sendEvent:(UIEvent *)event {
////  NSLog(@"event: %@", event);
//  [super sendEvent:event];
//}

//- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
//  NSLog(@"action %@", NSStringFromSelector(action));
//  return YES;
//}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
//  NSString * v = [event valueForKeyPath:@"_modifiedInput"];
//  if ([v isEqual:@"l"]) {
//    switched = YES;
//  }
//  if (switched) {
//    [event setValue:@"l " forKeyPath:@"_modifiedInput"];
//  }
//  [event setValue:@(1 << 21) forKey: @"_modifierFlags"];
  [super pressesBegan:presses withEvent:event];
  
}


@end

int main(int argc, char * argv[]) {
  @autoreleasepool {
    return UIApplicationMain(argc, argv, NSStringFromClass([TestApp class]), NSStringFromClass([AppDelegate class]));
  }
}
