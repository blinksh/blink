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
// along with Blink. If not, see <http://www.github.com/blinksh/blink>.
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

#import "LayoutConstraintManager.h"
#import "DeviceInfo.h"
#import <Blink-Swift.h>

@interface LayoutConstraintManager ()

@property (nonatomic, weak) UIView *managedView;
@property (nonatomic, weak) UIKeyboardLayoutGuide *keyboardGuide;
@property (nonatomic, assign) BKLayoutMode currentLayoutMode;
@property (nonatomic, assign) BOOL isLayoutLocked;
@property (nonatomic, assign) CGRect lockedFrame;

// Constraint properties
@property (nonatomic, strong) NSLayoutConstraint *topConstraint;
@property (nonatomic, strong) NSLayoutConstraint *leadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *trailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *bottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *bottomToKeyboardConstraint;
@property (nonatomic, strong) NSLayoutConstraint *minHeightConstraint;


@end

@implementation LayoutConstraintManager

+ (instancetype)managerForView:(UIView *)view 
                    layoutMode:(BKLayoutMode)mode 
                keyboardGuide:(UIKeyboardLayoutGuide *)keyboardGuide {
    LayoutConstraintManager *manager = [[LayoutConstraintManager alloc] init];
    manager.managedView = view;
    manager.keyboardGuide = keyboardGuide;
    manager.currentLayoutMode = mode;
    manager.isLayoutLocked = NO;
    
    [manager setupConstraints];
    [manager updateConstraintsForCurrentState];

    // DEBUG: observe keyboard hide to log state
    [[NSNotificationCenter defaultCenter] addObserver:manager
                                             selector:@selector(_debugKeyboardDidHide:)
                                                 name:UIKeyboardDidHideNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:manager
                                             selector:@selector(_debugKeyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];

    return manager;
}

- (void)setupConstraints {
    if (!self.managedView) return;
    
    UIView *view = self.managedView;
    UIView *superview = view.superview;
    if (!superview) return;
    
    // Set up autoresizing mask
    view.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Create constraints
    self.topConstraint = [view.topAnchor constraintEqualToAnchor:superview.topAnchor];
    self.leadingConstraint = [view.leadingAnchor constraintEqualToAnchor:superview.leadingAnchor];
    self.trailingConstraint = [view.trailingAnchor constraintEqualToAnchor:superview.trailingAnchor];
    
  self.bottomConstraint =
    [view.bottomAnchor constraintLessThanOrEqualToAnchor:superview.bottomAnchor constant:0];
  self.bottomConstraint.priority = UILayoutPriorityRequired; // 1000

  // Keyboard constraint
  if (self.keyboardGuide) {
      self.bottomToKeyboardConstraint =
        [view.bottomAnchor constraintEqualToAnchor:self.keyboardGuide.topAnchor];
      self.bottomToKeyboardConstraint.priority = UILayoutPriorityDefaultHigh; // 750 or 999

      // Optional: minimum height to avoid collapse
      self.minHeightConstraint =
        [view.heightAnchor constraintGreaterThanOrEqualToConstant:50];
      self.minHeightConstraint.priority = UILayoutPriorityRequired;
  }
    
    // Activate all constraints
    NSMutableArray *constraintsToActivate = [NSMutableArray arrayWithObjects:
        self.topConstraint,
        self.leadingConstraint,
        self.trailingConstraint,
        self.bottomConstraint,
        nil];
    
    if (self.bottomToKeyboardConstraint) {
        [constraintsToActivate addObject:self.bottomToKeyboardConstraint];
      [constraintsToActivate addObject: self.minHeightConstraint];
    }
    
    [NSLayoutConstraint activateConstraints:constraintsToActivate];
}

- (void)updateLayoutMode:(BKLayoutMode)mode {
    if (self.isLayoutLocked) return; // Don't update if locked
    
    self.currentLayoutMode = mode;
    [self updateConstraintsForCurrentState];
}

- (void)setLayoutLocked:(BOOL)locked withFrame:(CGRect)frame {
    self.isLayoutLocked = locked;
    self.lockedFrame = frame;
    
    if (locked) {
        // Store current constraint values as locked frame
        [self updateConstraintsForLockedFrame];
    } else {
        // Restore to normal layout mode behavior
        [self updateConstraintsForCurrentState];
    }
}

- (void)updateConstraintsForCurrentState {
    if (self.isLayoutLocked) {
        [self updateConstraintsForLockedFrame];
        return;
    }
    
    UIEdgeInsets insets = [self calculateInsetsForLayoutMode:self.currentLayoutMode];
    
    self.topConstraint.constant = insets.top;
    self.leadingConstraint.constant = insets.left;
    self.trailingConstraint.constant = -insets.right;
    self.bottomConstraint.constant = -insets.bottom;
}

- (void)updateConstraintsForLockedFrame {
    if (CGRectIsEmpty(self.lockedFrame)) return;
    
    UIView *superview = self.managedView.superview;
    if (!superview) return;
    
    // Calculate insets based on locked frame
    CGFloat top = self.lockedFrame.origin.y;
    CGFloat left = self.lockedFrame.origin.x;
    CGFloat right = superview.bounds.size.width - CGRectGetMaxX(self.lockedFrame);
    CGFloat bottom = superview.bounds.size.height - CGRectGetMaxY(self.lockedFrame);
    
    self.topConstraint.constant = top;
    self.leadingConstraint.constant = left;
    self.trailingConstraint.constant = -right;
    self.bottomConstraint.constant = -bottom;
}

- (UIEdgeInsets)calculateInsetsForLayoutMode:(BKLayoutMode)mode {
    UIView *view = self.managedView;
    UIWindow *window = view.window;
    if (!window) return UIEdgeInsetsZero;
    
    // Handle projection
    if (window == ShadowWindow.shared || window.windowScene.session.role == UIWindowSceneSessionRoleExternalDisplayNonInteractive) {
        return ShadowWindow.shared.refWindow.safeAreaInsets;
    }
    
    BOOL isExternal = (UIScreen.mainScreen != window.screen);

    UIEdgeInsets deviceMargins = window.safeAreaInsets;
    UIEdgeInsets result = UIEdgeInsetsZero;

    mode = [LayoutConstraintManager resolve:mode];

    switch (mode) {
        case BKLayoutModeCover:
            // No insets - full screen
            break;

        case BKLayoutModeSafeFit:
            result = deviceMargins;
            break;

        case BKLayoutModeFill: {
            if (isExternal) {
                result = deviceMargins;
                break;
            }
            if (!DeviceInfo.shared.hasCorners) {
                break;
            }
            CGFloat m = deviceMargins.top / 3.0;
            result.top = m;
            result.left = m;
            result.right = MAX(deviceMargins.right, m);
            result.bottom = m;
            break;
        }

        case BKLayoutModeDefault:
            NSAssert(NO, @"BKLayoutModeDefault should not reach geometry; +resolve: must convert it to a concrete mode.");
            break;
    }
    
    return result;
}

- (UIEdgeInsets)currentInsets {
    return UIEdgeInsetsMake(
        self.topConstraint.constant,
        self.leadingConstraint.constant,
        -self.trailingConstraint.constant,
        -self.bottomConstraint.constant
    );
}

- (void)debugLayoutState:(NSString *)context {
    UIView *view = self.managedView;
    UIView *superview = view.superview;

    NSLog(@"[LayoutDebug] === %@ ===", context);
    NSLog(@"[LayoutDebug] managedView frame: %@", NSStringFromCGRect(view.frame));
    NSLog(@"[LayoutDebug] superview frame: %@", NSStringFromCGRect(superview.frame));
    NSLog(@"[LayoutDebug] superview safeAreaInsets: %@", NSStringFromUIEdgeInsets(superview.safeAreaInsets));
    NSLog(@"[LayoutDebug] window safeAreaInsets: %@", NSStringFromUIEdgeInsets(view.window.safeAreaInsets));
    NSLog(@"[LayoutDebug] keyboardGuide layoutFrame: %@", NSStringFromCGRect(self.keyboardGuide.layoutFrame));
    NSLog(@"[LayoutDebug] bottomConstraint: constant=%.1f active=%d", self.bottomConstraint.constant, self.bottomConstraint.active);
    NSLog(@"[LayoutDebug] kbConstraint: constant=%.1f active=%d priority=%f",
          self.bottomToKeyboardConstraint.constant, self.bottomToKeyboardConstraint.active,
          (float)self.bottomToKeyboardConstraint.priority);
    NSLog(@"[LayoutDebug] layoutMode: %ld", (long)self.currentLayoutMode);
    NSLog(@"[LayoutDebug] screen height: %.1f", UIScreen.mainScreen.bounds.size.height);
}

- (void)_debugKeyboardDidHide:(NSNotification *)notification {
    [self debugLayoutState:@"keyboardDidHide notification"];
}

- (void)_debugKeyboardDidShow:(NSNotification *)notification {
    [self debugLayoutState:@"keyboardDidShow notification"];
}

+ (BKLayoutMode) deviceDefaultLayoutMode {
  return [self supportsLayoutMode:BKLayoutModeFill]
    ? BKLayoutModeFill
    : BKLayoutModeSafeFit;
}

+ (BKLayoutMode)resolve:(BKLayoutMode)mode {
  if (mode == BKLayoutModeDefault) {
    return [self deviceDefaultLayoutMode];
  }
  if (![self supportsLayoutMode:mode]) {
    return BKLayoutModeCover;
  }
  return mode;
}

+ (BOOL)supportsLayoutMode:(BKLayoutMode)mode {
  if (mode == BKLayoutModeFill) {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
  }
  return YES;
}

@end
