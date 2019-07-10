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
#import <WebKit/WebKit.h>
#import "MCPSessionParameters.h"

@class TermView;
@class TermDevice;
@class TermInput;


@protocol TermViewDeviceProtocol

@property BOOL rawMode;

- (BOOL)handleControl:(NSString *)control;
- (void)viewIsReady;
- (void)viewFontSizeChanged:(NSInteger)size;
- (void)viewWinSizeChanged:(struct winsize)win;
- (void)viewSendString:(NSString *)data;
- (void)viewCopyString:(NSString *)text;
- (void)viewShowAlert:(NSString *)title andMessage:(NSString *)message;

@end


@interface BKWebView: WKWebView

@end

@interface TermView : UIView

@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) BOOL hasSelection;
@property (nonatomic, readonly) NSURL *detectedLink;
@property (nonatomic, readonly) NSString *selectedText;
@property (nonatomic) id<TermViewDeviceProtocol> device;
@property (nonatomic) UIEdgeInsets additionalInsets;
@property (nonatomic) BOOL layoutLocked;
@property (nonatomic) CGRect layoutLockedFrame;



- (id)initWithFrame:(CGRect)frame andBgColor: (UIColor *)bgColor;
- (CGRect)webViewFrame;
- (void)loadWith:(MCPSessionParameters *)params;
- (void)reloadWith:(MCPSessionParameters *)params;
- (void)clear;
- (void)setWidth:(NSInteger)count;
- (void)setFontSize:(NSNumber *)newSize;
- (void)write:(NSString *)data;
- (void)setCursorBlink:(BOOL)state;
- (void)setBoldAsBright:(BOOL)state;
- (void)setBoldEnabled:(NSUInteger)state;
- (void)setIme:(NSString *)imeText completionHandler:(void (^ _Nullable)(_Nullable id, NSError * _Nullable error))completionHandler;
- (void)copy:(id _Nullable )sender;
- (void)pasteSelection:(id _Nullable)sender;
- (void)terminate;
- (void)reset;
- (void)restore;

- (void)blur;
- (void)focus;
- (void)reportTouchInPoint:(CGPoint)point;
- (void)cleanSelection;
- (void)increaseFontSize;
- (void)decreaseFontSize;
- (void)resetFontSize;
- (void)writeB64:(NSData * _Nonnull)data;

- (void)modifySideOfSelection;
- (void)modifySelectionInDirection:(NSString * _Nonnull)direction granularity:(NSString * _Nonnull)granularity;
@end
