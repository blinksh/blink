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

@class TermView;

@protocol TerminalDelegate <NSObject>

@property (readonly) TermView *termView;

- (void)write:(NSString *)input;

@optional
- (void)terminalIsReady: (NSDictionary *)size;
- (void)updateTermRows:(NSNumber *)rows Cols:(NSNumber *)cols;
- (void)fontSizeChanged:(NSNumber *)size;
- (void)focus;
- (void)blur;
//- (void)copy:(id)sender;
//- (void)increaseFontSize;
//- (void)decreaseFontSize;
//- (void)resetFontSize;
//- (void)openLink;

@end

@interface BLWebView: WKWebView

@end

@interface TermView : UIView

@property (weak) id<TerminalDelegate> termDelegate;
@property (nonatomic, readonly, weak) NSString *title;
@property (nonatomic, readonly) NSURL *detectedLink;
@property (nonatomic, readonly) NSString *selectedText;

- (id)initWithFrame:(CGRect)frame;
- (void)setScrollEnabled:(BOOL)scroll;
- (void)setRawMode:(BOOL)raw;
- (BOOL)rawMode;
- (void)clear;
- (void)setColumnNumber:(NSInteger)count;
- (void)setFontSize:(NSNumber *)newSize;
- (void)setInputEnabled:(BOOL)enabled;
- (void)loadTerminal;
- (void)write:(NSString *)data;
- (void)loadTerminalThemeJS:(NSString *)themeContent;
- (void)loadTerminalFont:(NSString *)familyName fromCSS:(NSString *)cssPath;
- (void)loadTerminalFont:(NSString *)familyName cssFontContent:(NSString *)cssContent;
- (void)setCursorBlink:(BOOL)state;
- (void)copy:(id)sender;
- (void)terminate;
- (void)reset;

- (void)blur;
- (void)focus;
- (void)cleanSelection;
- (void)increaseFontSize;
- (void)decreaseFontSize;
- (void)resetFontSize;

@end
