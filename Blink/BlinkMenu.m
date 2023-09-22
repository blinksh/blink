//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2023 Blink Mobile Shell Project
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
#import "BlinkMenu.h"
#import "BLKDefaults.h"
#import "Blink-Swift.h"
#import "GeoManager.h"

const BlinkActionID BlinkActionSnippets = @"blink-snippets";
const BlinkActionID BlinkActionTabClose = @"blink-tab-close";
const BlinkActionID BlinkActionTabCreate = @"blink-tab-create";
const BlinkActionID BlinkActionLayoutMenu = @"blink-layout-menu";
const BlinkActionID BlinkActionMoreMenu = @"blink-actions-more-menu";
const BlinkActionID BlinkActionChangeLayout = @"blink-change-layout";
const BlinkActionID BlinkActionToggleLayoutLock = @"blink-toggle-layout-lock";
const BlinkActionID BlinkActionToggleGeoTrack = @"blink-toggle-geo-track";
const BlinkActionID BlinkActionToggleCompactActions = @"blink-toggle-compact-actions";
const BlinkActionID BlinkActionLayoutFill = @"blink-layout-fill";
const BlinkActionID BlinkActionLayoutFit = @"blink-layout-fit";
const BlinkActionID BlinkActionLayoutCover = @"blink-layout-cover";

NSString * BLINK_ACTION_TOGGLE_PREFIX = @"blink-toggle-";

const BlinkActionAppearance BlinkActionAppearanceIcon = @"icon";
const BlinkActionAppearance BlinkActionAppearanceIconLeading = @"icon-leading";
const BlinkActionAppearance BlinkActionAppearanceIconTrailing = @"icon-trailing";
const BlinkActionAppearance BlinkActionAppearanceIconCircle = @"icon-circle";

const CGFloat MENU_ITEM_SPACING = 10.0;
const CGFloat MENU_PADDING = 10.0;

@interface DotsButton : UIButton

@end

@implementation DotsButton

- (instancetype)initWithConfiguration: (UIButtonConfiguration *)configuration {
  if (self = [super initWithFrame:CGRectZero]) {
    [self setConfiguration:configuration];
  }
  
  return self;
}

- (CGPoint)menuAttachmentPointForConfiguration:(UIContextMenuConfiguration *)configuration {
  CGPoint res = [super menuAttachmentPointForConfiguration:configuration];
  return CGPointMake(res.x, -24); // always at the top
}

@end


@implementation BlinkMenu {
  
  UIVisualEffectView *_effect;
  UIColor *_foregroundColor;
  UIColor *_backgroundColor;
  
  NSMutableArray<UIButton *> *_btnsInRow;
  NSArray<BlinkActionID> *_actions;
  NSArray<BlinkActionID> *_actionsBehindDots;
  NSArray<BlinkActionID> *_actionsAlwaysBehindDots;
  UIButton *_dotsBtn;
  BOOL _compact;
  
//  UIButtonConfigurationUpdateHandler _cfgUpdateHandler;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _tapToCloseView = [[UIView alloc] init];
    UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_onTap:)];
    [_tapToCloseView addGestureRecognizer:recognizer];
    
    
    _effect = [[UIVisualEffectView alloc] initWithEffect: [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
    _effect.layer.cornerRadius = 15.0; // 13.0 but 15.0 is more like Music.app bar
    _effect.layer.cornerCurve = kCACornerCurveContinuous;
    _effect.clipsToBounds = YES;
    
    
    _actions = @[];
    _btnsInRow = [@[] mutableCopy];
    _backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
      if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        return [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1];
      } else {
        return UIColor.whiteColor;
      }
    }];
    _foregroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
      if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        return UIColor.whiteColor;
      } else {
        return UIColor.blackColor;
      }
    }];
    
    _dotsBtn = [self buildButtonWithID:BlinkActionMoreMenu
                            appearance:BlinkActionAppearanceIconCircle];
    
    [_effect.contentView addSubview:_dotsBtn];
    [self addSubview:_effect];
    
    
    
  }
  return self;
}

- (void)_onTap:(UITapGestureRecognizer *)recognizer {
  [[self.delegate spaceController] toggleQuickActionsAction];
}

- (UIButton *)buildButtonWithID:(BlinkActionID)elementID appearance: (BlinkActionAppearance) ap {
  UIMenuElement *element = [self menuElementForID:elementID appearance: ap];
  if (element == nil) {
    NSLog(@"unknown elemnt id %@", elementID);
    return nil;
  }
  
  UIButtonConfiguration *cfg;
  
  if (ap == BlinkActionAppearanceIconLeading) {
    cfg = [UIButtonConfiguration borderedButtonConfiguration];
    cfg.imagePlacement = NSDirectionalRectEdgeLeading;
    cfg.baseForegroundColor = _foregroundColor;
//    cfg.baseBackgroundColor = _backgroundColor;
    cfg.imagePadding = 8;
  } else if (ap == BlinkActionAppearanceIconTrailing) {
    cfg = [UIButtonConfiguration borderedButtonConfiguration];
    cfg.imagePlacement = NSDirectionalRectEdgeTrailing;
    cfg.imagePadding = 8;
    cfg.baseForegroundColor = _foregroundColor;
  } else if (ap == BlinkActionAppearanceIcon) {
    if ([elementID hasPrefix:BLINK_ACTION_TOGGLE_PREFIX]) {
      cfg = [UIButtonConfiguration plainButtonConfiguration];
      cfg.baseForegroundColor = _foregroundColor;
    } else {
      cfg = [UIButtonConfiguration borderedButtonConfiguration];
      cfg.baseForegroundColor = _foregroundColor;
      cfg.baseBackgroundColor = [UIColor clearColor];
      //    cfg.imagePlacement = NSDirectionalRectEdgeNone;
      //    cfg.baseForegroundColor = _foregroundColor;
    }
  } else if (ap == BlinkActionAppearanceIconCircle) {
    cfg = [UIButtonConfiguration filledButtonConfiguration];
    cfg.imagePlacement = NSDirectionalRectEdgeNone;
    cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    cfg.baseForegroundColor = _foregroundColor;
    cfg.baseBackgroundColor = [UIColor clearColor];
  } else {
    cfg = [UIButtonConfiguration borderedButtonConfiguration];
    cfg.baseForegroundColor = _foregroundColor;
    cfg.baseBackgroundColor = _backgroundColor;
  }
    
  UIButton *btn;
  
  if ([element isMemberOfClass:[UIAction class]]) {
    UIAction *action = (UIAction *)element;
    btn = [UIButton buttonWithConfiguration:cfg primaryAction:action];
    if ([elementID hasPrefix:BLINK_ACTION_TOGGLE_PREFIX]) {
      [btn setChangesSelectionAsPrimaryAction:YES];
      [btn setSelected: action.state == UIMenuElementStateOn];
    }
  } else if ([element isMemberOfClass:[UIMenu class]]) {
    if (elementID == BlinkActionMoreMenu) {
      btn = [[DotsButton alloc] initWithConfiguration:cfg];
    } else {
      btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    }
    btn.menu = (UIMenu *)element;
    [btn setShowsMenuAsPrimaryAction:YES];
    
    // UIButton doesn't pickup title and image from menu for some reason
    [btn setImage:element.image forState:UIControlStateNormal];
    if (ap != BlinkActionAppearanceIcon && ap != BlinkActionAppearanceIconCircle) {
      [btn setTitle:element.title forState:UIControlStateNormal];
    }
    if (elementID == BlinkActionMoreMenu) {
      [btn sizeToFit];
    }
  }
  
//  if (ap == nil) {
    // remove icon for non icon styles
//    btn.configuration.image = nil;
//    [btn setImage:nil forState:UIControlStateNormal];
//    [btn setImage:nil forState:UIControlStateDisabled];
//  } else if (ap == BlinkActionAppearanceIcon || ap == BlinkActionAppearanceIconCircle) {
    // remove title for icon only styles
//    btn.configuration.title = nil;
//    [btn setTitle:nil forState:UIControlStateNormal];
//    [btn setTitle:nil forState:UIControlStateDisabled];
//  }
  
  // hover effect
  btn.pointerInteractionEnabled = true;

  return btn;
}

- (void)buildMenuWithIDs:(NSArray<BlinkActionID> *)ids andAppearance:(NSDictionary<BlinkActionID, BlinkActionAppearance> *) appearance {
  _actions = ids;
  for (UIButton *btn in _btnsInRow) {
    [btn removeFromSuperview];
  }
  
  [_btnsInRow removeAllObjects];
  
  
  for (BlinkActionID elementID in ids) {
    BlinkActionAppearance ap = appearance[elementID];
    UIButton *btn = [self buildButtonWithID:elementID appearance:ap];
    if (btn) {
      [_btnsInRow addObject:btn];
      [_effect.contentView addSubview:btn];
    }
  }
}

- (UIMenuElement *)menuElementForID:(BlinkActionID) elementID appearance: (BlinkActionAppearance) ap {
  BOOL noTitle = ap == BlinkActionAppearanceIcon || ap == BlinkActionAppearanceIconCircle;
  __weak __block id<CommandsHUDDelegate> delegate = _delegate;
  if (elementID == BlinkActionSnippets) {
    return [UIAction
            actionWithTitle:noTitle ? @"" : @"Snips"
            image:[UIImage systemImageNamed:@"chevron.left.square"]
            identifier:elementID handler:^(__kindof UIAction * _Nonnull action) {
      [[delegate spaceController] showSnippetsAction];      
    }];
  }
  
  if (elementID == BlinkActionTabClose) {
    return [UIAction
            actionWithTitle:noTitle ? @"" : @"Close"
            image:[UIImage systemImageNamed:@"xmark.rectangle"]
            identifier:elementID handler:^(__kindof UIAction * _Nonnull action) {
      [[delegate spaceController] closeShellAction];
    }];
  }
  
  if (elementID == BlinkActionLayoutFit) {
    UIAction *action = [UIAction
            actionWithTitle:noTitle ? @"" : @"Fit"
            image:nil
            identifier:elementID handler:^(__kindof UIAction * _Nonnull action) {
      [delegate.currentTerm unlockLayout];
      delegate.currentTerm.sessionParams.layoutMode = BKLayoutModeSafeFit;
      [self.superview setNeedsLayout];
      
    }
    ];
    action.state = delegate.currentTerm.sessionParams.layoutMode == BKLayoutModeSafeFit ? UIMenuElementStateOn : UIMenuElementStateOff;
    return action;
  }
  if (elementID == BlinkActionLayoutFill) {
    UIAction *action = [UIAction
            actionWithTitle:noTitle ? @"" : @"Fill"
            image:nil
            identifier:elementID handler:^(__kindof UIAction * _Nonnull action) {
      [delegate.currentTerm unlockLayout];
      delegate.currentTerm.sessionParams.layoutMode = BKLayoutModeFill;
      [self.superview setNeedsLayout];
    }
    ];
    action.state = delegate.currentTerm.sessionParams.layoutMode == BKLayoutModeFill ? UIMenuElementStateOn : UIMenuElementStateOff;
    return action;
  }
  
  if (elementID == BlinkActionLayoutCover) {
    UIAction * action = [UIAction
            actionWithTitle:noTitle ? @"" : @"Cover"
            image:nil
            identifier:elementID handler:^(__kindof UIAction * _Nonnull action) {
      [delegate.currentTerm unlockLayout];
      delegate.currentTerm.sessionParams.layoutMode = BKLayoutModeCover;
      [self.superview setNeedsLayout];
    }
    ];
    action.state = delegate.currentTerm.sessionParams.layoutMode == BKLayoutModeCover ? UIMenuElementStateOn : UIMenuElementStateOff;
    return action;
  }
  
  if (elementID == BlinkActionTabCreate) {
    return [UIAction
            actionWithTitle:noTitle ? @"" : @"Create"
            image:[UIImage systemImageNamed:@"plus.rectangle.on.rectangle"] identifier:elementID handler:^(__kindof UIAction * _Nonnull action) {
      [[delegate spaceController] newShellAction];
    }];
  }
  
  if (elementID == BlinkActionToggleGeoTrack) {
    UIAction *action = [UIAction
                        actionWithTitle:noTitle ? @"" : @"Geo"
            image:[UIImage systemImageNamed:@"location"]
            identifier:elementID handler:^(__kindof UIAction * _Nonnull action) {
      [[delegate spaceController] toggleGeoTrack];
    }];
    action.state = GeoManager.shared.traking ? UIMenuElementStateOn : UIMenuElementStateOff;
    
    return action;
  }
  
  if (elementID == BlinkActionToggleCompactActions) {
    UIAction * action = [UIAction
                         actionWithTitle:noTitle ? @"" : @"Compact"
                         image:nil
                         identifier:elementID handler:^(__kindof UIAction * _Nonnull action) {
      
      [BLKDefaults setCompactQuickActions:!BLKDefaults.compactQuickActions];
      [BLKDefaults saveDefaults];
      
      [self.superview setNeedsLayout];
    }];
//    action.attributes = UIMenuElementAttributesKeepsMenuPresented;
    action.state = BLKDefaults.compactQuickActions ? UIMenuElementStateOn : UIMenuElementStateOff;
    return action;
  }
  
  if (elementID == BlinkActionToggleLayoutLock) {
    UIAction *action = [UIAction
                        actionWithTitle:noTitle ? @"" : @"Lock"
            image:[UIImage systemImageNamed:@"lock.rectangle"]
            identifier:elementID handler:^(__kindof UIAction * _Nonnull action) {
      [delegate.currentTerm toggleLayoutLock];
      [self.superview setNeedsLayout];
    }];
    action.state = delegate.currentTerm.sessionParams.layoutLocked ? UIMenuElementStateOn : UIMenuElementStateOff;
    return action;
  }
  
  if (elementID == BlinkActionLayoutMenu) {
    return [UIMenu menuWithTitle:noTitle ? @"" : @"Layout"
                           image: [UIImage systemImageNamed:@"squareshape.squareshape.dashed"]
                      identifier:BlinkActionLayoutMenu options:UIMenuOptionsDisplayInline children:@[
      [self menuElementForID:BlinkActionLayoutFit appearance:nil],
      [self menuElementForID:BlinkActionLayoutFill appearance:nil],
      [self menuElementForID:BlinkActionLayoutCover appearance:nil]
    ]];
  }
  
  
  if (elementID == BlinkActionMoreMenu) {
    return [UIMenu menuWithTitle:@"More"
                           image: [UIImage systemImageNamed:@"ellipsis"]
                      identifier:BlinkActionLayoutMenu options:UIMenuOptionsDisplayInline children:@[
//      [self menuElementForID:BlinkActionChangeLayout appearance:nil]
    ]];
  }
  
  return nil;
}

- (CGSize)layoutForSize:(CGSize)size {
  _tapToCloseView.frame = CGRectMake(0, 0, size.width, size.height);
  BOOL needsCompactMode = false;
  CGFloat windowPadding = 20;
  if (BLKDefaults.compactQuickActions || size.width <= 570) {
    needsCompactMode = true;
  }
  
  if (size.width < 400) {
    windowPadding = 16;
  }
  
  BOOL fullRebuild = false;
  if (_compact != needsCompactMode) {
    fullRebuild = true;
    _compact = needsCompactMode;
  }
  
  
  
  if (fullRebuild) {
    return [self _rebuildForWidth: size.width - windowPadding];
  } else {
    return [self _rebuildForWidth: size.width - windowPadding];
  }
}

-(CGSize)_rebuildForWidth: (CGFloat)width {
  for (UIButton * btn in _btnsInRow) {
    [btn removeFromSuperview];
  }
  [_btnsInRow removeAllObjects];
  BlinkActionAppearance ap = _compact ? BlinkActionAppearanceIcon : BlinkActionAppearanceIconLeading;
  
  CGSize dotsSize = _dotsBtn.intrinsicContentSize;
  width -= MENU_ITEM_SPACING + dotsSize.width;
  
  CGFloat left = MENU_PADDING;
  CGFloat top = MENU_PADDING;
  
  NSMutableArray<UIMenuElement *> *dotsElements = nil;
  
  for (BlinkActionID actionID in _actions) {
    if (dotsElements) {
      UIMenuElement *element = [self menuElementForID:actionID appearance:nil];
      if (element) {
        [dotsElements addObject:element];
      }
    } else {
      UIButton *btn = [self buildButtonWithID:actionID appearance:ap];
      CGSize btnSize = btn.intrinsicContentSize;
      if (btnSize.width + MENU_ITEM_SPACING <= width) {
        [_effect.contentView addSubview:btn];
        [_btnsInRow addObject:btn];
        [btn setFrame:CGRectMake(left, top, btnSize.width, btnSize.height)];
        left += btnSize.width + MENU_ITEM_SPACING;
        width -= btnSize.width + MENU_ITEM_SPACING;
      } else {
        dotsElements = [[NSMutableArray alloc] init];
        UIMenuElement *element = [self menuElementForID:actionID appearance:nil];
        if (element) {
          [dotsElements addObject:element];
        }
      }
    }
  }
  
  [_dotsBtn setFrame:CGRectMake(left, top, dotsSize.width, dotsSize.height)];
  
  NSMutableArray *elements = [[NSMutableArray alloc] init];
  for (BlinkActionID elementID in @[BlinkActionToggleCompactActions]) {
    UIMenuElement *element = [self menuElementForID:elementID appearance:nil];
    if (element) {
      [elements addObject:element];
    }
  }
  
  
  UIMenu * dotsMenu = [UIMenu menuWithTitle:@"..." image:nil identifier:@"dots.menu" options:UIMenuOptionsDisplayInline children:elements];
  
  UIMenu *menu = [UIMenu menuWithTitle:@"" image:nil identifier:@"dots.menu.more" options:UIMenuOptionsDisplayInline children:dotsElements];
  
  if (dotsElements.count == 0) {
    _dotsBtn.menu = dotsMenu;
  } else {
    _dotsBtn.menu = [UIMenu menuWithChildren:@[menu, dotsMenu]];
  }
  
  
  return CGSizeMake(left + dotsSize.width + MENU_PADDING, top + dotsSize.height + MENU_PADDING);
}

- (void)layoutSubviews {
  [super layoutSubviews];
  _effect.frame = self.bounds;
  CGFloat left = MENU_PADDING;
  CGFloat top = MENU_PADDING;
  for (UIButton *btn in _btnsInRow) {
    CGSize btnSize = btn.intrinsicContentSize;
    [btn setFrame:CGRectMake(left, top, btnSize.width, btnSize.height)];
    left += btnSize.width + MENU_ITEM_SPACING;
  }
}

- (CGSize)intrinsicContentSize {
  CGSize size = CGSizeMake(0, 0);
  for (UIButton *btn in _btnsInRow) {
    CGSize btnSize = btn.intrinsicContentSize;
    size.width += btnSize.width;
    size.height = MAX(size.height, btnSize.height);
  }
  size.width += MENU_PADDING * 2;
  NSInteger count = _btnsInRow.count;
  if (count > 1) {
    size.width += (count - 1) * MENU_ITEM_SPACING;
  }
  size.height += MENU_PADDING * 2;
  
  return size;
}

- (void)removeFromSuperview {
  [super removeFromSuperview];
  [_tapToCloseView removeFromSuperview];
}

@end
