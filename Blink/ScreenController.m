//
//  ScreenController.m
//  Blink
//
//  Created by Yury Korolev on 31/12/2016.
//  Copyright © 2016 Carlos Cabañero Projects SL. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ScreenController.h"
#import "SpaceController.h"

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
  }
  return self;
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
  
  [[_windows firstObject] makeKeyAndVisible];

  // We have already connected external screen
  if ([UIScreen screens].count > 1) {
    [self setupWindowForScreen:[[UIScreen screens] lastObject]];
  }
}

- (void)setupWindowForScreen:(UIScreen *)screen
{
  UIWindow *window = [[UIWindow alloc] initWithFrame:[screen bounds]];
  [_windows addObject:window];
  
  window.screen = screen;
  window.rootViewController = [self createSpaceController];
  window.hidden = NO;
}

- (SpaceController *)createSpaceController
{
  UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil];
  return [storyboard instantiateViewControllerWithIdentifier:@"SpaceController"];
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

@end
