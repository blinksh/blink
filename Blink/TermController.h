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

#import "TermView.h"
#import "MCPSessionParameters.h"
#import "StateManager.h"
#import "TermInput.h"

@class TermController;

@protocol TermControlDelegate <NSObject>

// terminalReady to start a specific session from the delegate, instead of inside the class.
//- (void)terminalReady:(TermStream *)stream;
- (void)terminalHangup:(TermController *)control;
- (void)terminalDidResize:(TermController*)control;

@end

@interface TermController : UIViewController<SecureRestoration>

@property (readonly) FILE *termout;
@property (readonly) FILE *termin;
@property (readonly) FILE *termerr;
@property (readonly) struct winsize *termsz;
@property (readonly, strong, nonatomic) TermView *termView;
@property (readonly, strong, nonatomic) TermInput *termInput;
@property (nonatomic) BOOL rawMode;
@property (weak) id<TermControlDelegate> delegate;
@property (strong, nonatomic) NSString* activityKey;
@property (strong) NSString* sessionStateKey;
@property (strong) MCPSessionParameters *sessionParameters;

- (void)write:(NSString *)input;
- (void)terminate;
- (void)suspend;
- (void)resume;
- (void)focus;
- (void)blur;
- (void)reload;

- (void)attachInput:(TermInput *)termInput;

@end
