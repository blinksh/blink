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


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString * BlinkActionID NS_TYPED_EXTENSIBLE_ENUM;

extern const BlinkActionID BlinkActionSnippets;
extern const BlinkActionID BlinkActionTabClose;
extern const BlinkActionID BlinkActionTabCreate;
extern const BlinkActionID BlinkActionLayoutMenu;
extern const BlinkActionID BlinkActionMoreMenu;
extern const BlinkActionID BlinkActionChangeLayout;
extern const BlinkActionID BlinkActionToggleLayoutLock;
extern const BlinkActionID BlinkActionToggleGeoTrack;
extern const BlinkActionID BlinkActionToggleCompactActions;

extern NSString * BLINK_ACTION_TOGGLE_PREFIX;
typedef NSString * BlinkActionAppearance NS_TYPED_EXTENSIBLE_ENUM;

extern const BlinkActionAppearance BlinkActionAppearanceIcon;
extern const BlinkActionAppearance BlinkActionAppearanceIconLeading;
extern const BlinkActionAppearance BlinkActionAppearanceIconTrailing;
extern const BlinkActionAppearance BlinkActionAppearanceIconCircle;

@class TermController;
@class SpaceController;

@protocol CommandsHUDDelegate <NSObject>

- (TermController * _Nullable)currentTerm;
- (SpaceController * _Nullable)spaceController;

@end


@interface BlinkMenu : UIView

@property __nullable __weak id<CommandsHUDDelegate> delegate;

@property UIView *tapToCloseView;

- (CGSize)layoutForSize:(CGSize)size;
- (void)buildMenuWithIDs:(NSArray<BlinkActionID> *)ids andAppearance:(NSDictionary<BlinkActionID, BlinkActionAppearance> *) appearance;

@end


NS_ASSUME_NONNULL_END
