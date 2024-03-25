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

#import <Foundation/Foundation.h>
#import "TermStream.h"
#import "TermView.h"
#include <sys/ioctl.h>

@class TermDevice;

@protocol TermInput <NSObject>

@property (weak) TermDevice *device;
@property BOOL secureTextEntry;

- (void)setHasSelection:(BOOL)value;
- (void)reset;

@end


@protocol TermDeviceDelegate

- (void)deviceIsReady;
- (void)deviceSizeChanged;
- (void)viewFontSizeChanged:(NSInteger)size;
- (BOOL)handleControl:(NSString *)control;
- (void)lineSubmitted:(NSString *)line;
- (void)deviceFocused;
- (void)apiCall:(NSString *)api andRequest:(NSString *)request;
- (void)viewNotify:(NSDictionary *)data;
- (void)viewDidReceiveBellRing;
- (UIViewController *)viewController;

@end

@interface TermDevice : NSObject {
  @public struct winsize win;
}

@property (nonatomic) struct winsize win;
@property (readonly) TermStream *stream;
@property (readonly) TermView *view;
@property (readonly) UIView<TermInput> *input;
@property id<TermDeviceDelegate> delegate;
@property (nonatomic) BOOL rawMode;
@property (nonatomic) BOOL autoCR;
@property (nonatomic) BOOL secureTextEntry;
@property (nonatomic) NSInteger rows;
@property (nonatomic) NSInteger cols;

// Offer the pointer as it is a struct on itself. This is helpful because on Swift,
// we cannot used a synthesized expression to get the UnsafeMutablePointer.
- (struct winsize *)window;
- (void)attachInput:(UIView<TermInput> *)termInput;
- (void)attachView:(TermView *)termView;

- (void)onSubmit:(NSString *)line;
- (void)prompt:(NSString *)prompt secure:(BOOL)secure shell:(BOOL)shell;
- (NSString *)readline:(NSString *)prompt secure:(BOOL)secure;
- (void)closeReadline;

- (void)focus;
- (void)blur;

- (void)write:(NSString *)input;
- (void)writeIn:(NSString *)input;
- (void)writeInDirectly:(NSString *)input;
- (void)writeOut:(NSString *)output;
- (void)writeOutLn:(NSString *)output;
- (void)close;


@end

@interface TermDevice () <TermViewDeviceProtocol>
@end
