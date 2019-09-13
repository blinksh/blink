//////////////////////////////////////////////////////////////////////////////////
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


#import "LayoutManager.h"
#import "DeviceInfo.h"


CGFloat __mainWindowKBBottomInset = 0;

NSString * LayoutManagerBottomInsetDidUpdate = @"LayoutManagerBottomInsetDidUpdate";
NSTimer *__debounceTimer = nil;

@implementation LayoutManager {

}

+ (CGFloat) mainWindowKBBottomInset {
  return __mainWindowKBBottomInset;
}

+ (void) updateMainWindowKBBottomInset:(CGFloat) bottomInset {
  if (__mainWindowKBBottomInset == bottomInset) {
    return;
  }

  __mainWindowKBBottomInset = bottomInset;
  [__debounceTimer invalidate];
  
  __debounceTimer = [NSTimer scheduledTimerWithTimeInterval:0.3 repeats:NO block:^(NSTimer * _Nonnull timer) {
    [NSNotificationCenter.defaultCenter postNotificationName:LayoutManagerBottomInsetDidUpdate object:nil];
  }];
}

+ (BKLayoutMode) deviceDefaultLayoutMode {
  DeviceInfo *device = [DeviceInfo shared];
  if (device.hasNotch) {
    return BKLayoutModeSafeFit;
  }
  
  if (device.hasCorners) {
    return BKLayoutModeFill;
  }
  
  return BKLayoutModeCover;
}


+ (UIEdgeInsets) buildSafeInsetsForController:(UIViewController *)ctrl andMode:(BKLayoutMode) mode {
  
  UIScreen *mainScreen = UIScreen.mainScreen;
  UIWindow *window = ctrl.view.window;
  UIEdgeInsets deviceMargins = window.safeAreaInsets;// UIEdgeInsetsZero;// ctrl.viewDeviceSafeMargins;
  BOOL isMainScreen = window.screen == mainScreen;
  
  
  
  // we are on external monitor, so we use device margins to accomodate overscan and ignore mode
  // it is like BKLayoutModeSafeFit mode
  if (!isMainScreen) {
    return  deviceMargins;
  }
  
  BOOL fullScreen = CGRectEqualToRect(mainScreen.bounds, window.bounds);
  CGFloat slideOverVerticalMargin = (mainScreen.bounds.size.height - window.bounds.size.height) * 0.5;
  
  UIEdgeInsets result = UIEdgeInsetsZero;
  
  switch (mode) {
    case BKLayoutModeDefault:
      return [self buildSafeInsetsForController:ctrl andMode:[self deviceDefaultLayoutMode]];
    case BKLayoutModeCover:
      break;
    case BKLayoutModeSafeFit:
      result = deviceMargins;
      if (DeviceInfo.shared.hasCorners &&
          UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        result.top = 16;
        result.bottom = 16;
      }
      
      break;
    case BKLayoutModeFill: {
      DeviceInfo *deviceInfo = DeviceInfo.shared;
      
      if (!deviceInfo.hasCorners) {
        break;
      }
      
      if (!deviceInfo.hasNotch) {
        result.top = 5;
        result.left = 5;
        result.right = MAX(deviceMargins.right, 5);
        result.bottom = fullScreen ? 5 : 10;
        break;
      }
      
      UIDeviceOrientation orientation = UIDevice.currentDevice.orientation;
      
      if (UIDeviceOrientationIsPortrait(orientation)) {
        result.top = deviceMargins.top - 10;
        result.bottom = deviceMargins.bottom - 10;
        break;
      }
      
      if (orientation == UIDeviceOrientationLandscapeLeft) {
        result.left = deviceMargins.left - 4; // notch
        result.right = 10;
        result.top = 10;
        result.bottom = 8;
        break;
      }
      
      if (orientation == UIDeviceOrientationLandscapeRight) {
        result.right = deviceMargins.right - 4;  // notch
        result.left = 10;
        result.top = 10;
        result.bottom = 8;
        break;
      }
      
      result = deviceMargins;
    }
  }
  
  result.bottom = MAX(result.bottom, __mainWindowKBBottomInset);
  
  if (slideOverVerticalMargin > 0 && result.bottom > slideOverVerticalMargin) {
    result.bottom -= slideOverVerticalMargin;
  }
  
  return result;
}

+ (NSString *) layoutModeToString:(BKLayoutMode)mode {
  switch (mode) {
    case BKLayoutModeFill:
      return @"Fill";
    case BKLayoutModeCover:
      return @"Cover";
    case BKLayoutModeSafeFit:
      return @"Fit";
    default:
      return @"Default";
  }
}

@end
