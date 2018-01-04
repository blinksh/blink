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

#import <UIKit/UIKit.h>
#import "ScreenController.h"
#import "SpaceController.h"
#import "StateManager.h"

NSString * const MainSpaceControllerKey = @"MainSpaceControllerKey";
NSString * const SecondarySpaceControllerKey = @"SecondarySpaceControllerKey";

@interface UIWindow (ScreenController)
- (SpaceController *)spaceController;
@end

@implementation UIWindow (ScreenController)
- (SpaceController *)spaceController
{
  return (SpaceController *)self.rootViewController;
}
@end


@implementation ScreenController
{
  NSMutableArray<UIWindow *> *_windows;
  NSMutableDictionary *_bootControllers;
}

+ (ScreenController *)shared {
  static ScreenController *ctrl = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    ctrl = [[self alloc] init];
  });
  return ctrl;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _windows = [[NSMutableArray alloc] init];
    _bootControllers = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (UIViewController *)mainScreenRootViewController {
  return [[_windows firstObject] rootViewController];
}

- (void)subscribeForScreenNotifications
{
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  
  [defaultCenter addObserver:self
                    selector:@selector(screenDidConnect:)
                        name:UIScreenDidConnectNotification
                      object:nil];
  [defaultCenter addObserver:self
                    selector:@selector(screenDidDisconnect:)
                        name:UIScreenDidDisconnectNotification
                      object:nil];
}

- (void)setup
{
  [self subscribeForScreenNotifications];
  
  [self setupWindowForScreen:[UIScreen mainScreen]];
  
  UIWindow *mainWindow = [_windows firstObject];
  [mainWindow makeKeyAndVisible];
  
  SpaceController * secondarySC = _bootControllers[SecondarySpaceControllerKey];
  
  // We have already connected external screen
  if ([UIScreen screens].count > 1) {
    [self setupWindowForScreen:[[UIScreen screens] lastObject]];
  } else if (secondarySC) {
    SpaceController *mainSC = [mainWindow spaceController];
    [mainSC moveAllShellsFromSpaceController:secondarySC];
  }
  _bootControllers = nil;
}


- (void)setupWindowForScreen:(UIScreen *)screen
{
  UIWindow *window = [[UIWindow alloc] initWithFrame:[screen bounds]];
  
  [_windows addObject:window];
  
  NSString *rootControllerIdentifier =
    screen == [UIScreen mainScreen] ? MainSpaceControllerKey : SecondarySpaceControllerKey;
  
  window.screen = screen;
  window.rootViewController = [self createSpaceController: rootControllerIdentifier];
  window.hidden = NO;
}

- (SpaceController *)createSpaceController: (NSString *)identifier;
{
  SpaceController *spaceController = _bootControllers[identifier] ?: [[SpaceController alloc] init];
  spaceController.restorationIdentifier = identifier;
  spaceController.restorationClass = [ScreenController class];
  return spaceController;
}

- (void)screenDidConnect:(NSNotification *) notification
{
  UIScreen *screen = (UIScreen *)notification.object;
  [self setupWindowForScreen:screen];
}

- (void)screenDidDisconnect:(NSNotification *) notification
{
  SpaceController *mainSC = _windows.firstObject.spaceController;
  SpaceController *removingSC = _windows.lastObject.spaceController;
 
  [mainSC moveAllShellsFromSpaceController:removingSC];
  [_windows removeLastObject];
}

- (UIWindow *)keyWindow
{
  if ([[_windows firstObject] isKeyWindow]) {
    return [_windows firstObject];
  } else {
    return [_windows lastObject];
  }
}

- (UIWindow *)nonKeyWindow
{
  if ([[_windows firstObject] isKeyWindow]) {
    return [_windows lastObject];
  } else {
    return [_windows firstObject];
  }
}

- (void)switchToOtherScreen
{
  if ([_windows count] == 1) {
    return;
  }
  
  UIWindow *willBeKeyWindow = [self nonKeyWindow];
  
  [[willBeKeyWindow spaceController] viewScreenWillBecomeActive];
 
  [willBeKeyWindow makeKeyAndVisible];
}

- (void)moveCurrentShellToOtherScreen
{
  if ([_windows count] == 1) {
    return;
  }
  
  SpaceController *keySpaceCtrl = [[self keyWindow] spaceController];
  SpaceController *nonKeySpaceCtrl = [[self nonKeyWindow] spaceController];
  
  [nonKeySpaceCtrl moveCurrentShellFromSpaceController:keySpaceCtrl];
}

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
  NSString *identifier = [identifierComponents lastObject];
  
  if ([identifier isEqualToString:MainSpaceControllerKey] || [identifier isEqualToString:SecondarySpaceControllerKey]) {
    StateManager *stateManager = [[StateManager alloc] init];
    [stateManager load];

    SpaceController *spaceController = [[SpaceController alloc] init];
    spaceController.restorationIdentifier = identifier;
    [spaceController decodeRestorableStateWithCoder:coder andStateManager: stateManager];
    [ScreenController shared]->_bootControllers[identifier] = spaceController;
    return spaceController;
  }
  
  return nil;
}

- (void)suspend
{
  StateManager *stateManager = [[StateManager alloc] init];
  
  for (UIWindow *win in _windows) {
    [[win spaceController] suspendWith:stateManager];
  }
  
  [stateManager save];
}

- (void)resume
{
  StateManager *stateManager = [[StateManager alloc] init];
  [stateManager load];
  
  for (UIWindow *win in _windows) {
    [[win spaceController] resumeWith:stateManager];
  }
  [stateManager reset];
  [stateManager save];
}


@end
