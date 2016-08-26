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
#import <WebKit/WebKit.h>

extern NSString * const TermViewCtrlSeq;
extern NSString * const TermViewEscSeq;

@protocol TerminalDelegate

- (void)write:(NSString *)input;

@end

@interface TerminalView : UIView

@property (nonatomic) WKWebView *webView;
@property (weak) id<TerminalDelegate> delegate;
@property (nonatomic, readonly, weak) NSString *title;

- (id)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration;
- (void)setScrollEnabled:(BOOL)scroll;
- (void)setRawMode:(BOOL)raw;
- (BOOL)rawMode;
- (void)loadTerminal;
- (void)write:(NSString *)data;
- (void)assignSequence:(NSString *)seq toModifier:(UIKeyModifierFlags)modifier;
@end
