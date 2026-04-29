//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2019 Blink Mobile Shell Project
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "BLKDefaults.h"

NS_ASSUME_NONNULL_BEGIN

@class LayoutConstraintManager;

@interface LayoutConstraintManager : NSObject

// Setup constraints for a view with layout mode and keyboard guide
+ (instancetype)managerForView:(UIView *)view 
                    layoutMode:(BKLayoutMode)mode 
                keyboardGuide:(UIKeyboardLayoutGuide *)keyboardGuide;

+ (BKLayoutMode) deviceDefaultLayoutMode;

+ (BKLayoutMode)resolve:(BKLayoutMode)mode;

// Update layout mode
- (void)updateLayoutMode:(BKLayoutMode)mode;

// Handle layout lock
- (void)setLayoutLocked:(BOOL)locked withFrame:(CGRect)frame;

// Note: Keyboard handling is now automatic via constraint priorities

// Update keyboard layout guide (for window changes)
- (void)updateKeyboardLayoutGuide:(nullable UIKeyboardLayoutGuide *)keyboardGuide;

// Get current constraint constants for debugging
- (UIEdgeInsets)currentInsets;

// Debug: log layout state to console
- (void)debugLayoutState:(NSString *)context;

@end

NS_ASSUME_NONNULL_END
