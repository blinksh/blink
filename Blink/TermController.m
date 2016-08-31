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

#import "TermController.h"
#import "BKDefaults.h"
#import "BKKeyboardModifierViewController.h"
#import "BKSettingsNotifications.h"
#import "MCPSession.h"
#import "Session.h"
#import "fterm.h"

static NSDictionary *bkModifierMaps = nil;

@interface TermController () <WKScriptMessageHandler, TerminalDelegate, SessionDelegate>
@end

@implementation TermController {
  int _pinput[2];
  MCPSession *_session;
  BOOL _viewIsLocked;
}

+ (void)initialize
{
  bkModifierMaps = @{
    BKKeyboardModifierCtrl : [NSNumber numberWithInt:UIKeyModifierControl],
    BKKeyboardModifierAlt : [NSNumber numberWithInt:UIKeyModifierAlternate],
    BKKeyboardModifierCmd : [NSNumber numberWithInt:UIKeyModifierCommand],
    BKKeyboardModifierCaps : [NSNumber numberWithInt:UIKeyModifierAlphaShift],
    BKKeyboardModifierShift : [NSNumber numberWithInt:UIKeyModifierShift]
  };
}

- (void)write:(NSString *)input
{
  // Trasform the string and write it, with the correct sequence
  const char *str = [input UTF8String];
  write(_pinput[1], str, [input lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
}

- (void)loadView
{
  [super loadView];
  WKWebViewConfiguration *theConfiguration = [[WKWebViewConfiguration alloc] init];
  [theConfiguration.userContentController addScriptMessageHandler:self name:@"interOp"];
  _terminal = [[TerminalView alloc] initWithFrame:self.view.frame configuration:theConfiguration];
  _terminal.delegate = self;

  self.view = _terminal;

  [self configureTerminal];
  [self listenToControlEvents];
}

- (void)configureTerminal
{
  for (NSString *key in [BKDefaults keyboardKeyList]) {
    NSString *sequence = [BKDefaults keyboardMapping][key];
    [self assignSequence:sequence toModifier:[bkModifierMaps[key] integerValue]];
  }
  if ([BKDefaults isShiftAsEsc]) {
    [_terminal assignKey:UIKeyInputEscape toModifier:UIKeyModifierShift];
  }
  if ([BKDefaults isCapsAsEsc]) {
    [_terminal assignKey:UIKeyInputEscape toModifier:UIKeyModifierAlphaShift];
  }
  for (NSString *func in [BKDefaults keyboardFuncTriggers].allKeys) {
    NSArray *triggers = [BKDefaults keyboardFuncTriggers][func];
    [self assignFunction:func toTriggers:triggers];
  }
}

- (void)assignSequence:(NSString *)seq toModifier:(NSInteger)modifier
{
  if ([seq isEqual:BKKeyboardSeqNone]) {
    [_terminal assignSequence:nil toModifier:modifier];
  } else if ([seq isEqual:BKKeyboardSeqCtrl]) {
    [_terminal assignSequence:TermViewCtrlSeq toModifier:modifier];
  } else if ([seq isEqual:BKKeyboardSeqEsc]) {
    [_terminal assignSequence:TermViewEscSeq toModifier:modifier];
  }
}

- (void)assignFunction:(NSString *)func toTriggers:(NSArray *)triggers
{
  UIKeyModifierFlags modifiers = 0;
  for (NSString *t in triggers) {
    NSNumber *modifier = bkModifierMaps[t];
    modifiers = modifiers | modifier.intValue;
  }
  if ([func isEqual:BKKeyboardFuncCursorTriggers]) {
    [_terminal assignFunction:TermViewCursorFuncSeq toTriggers:modifiers];
  } else if ([func isEqual:BKKeyboardFuncFTriggers]) {
    [_terminal assignFunction:TermViewFFuncSeq toTriggers:modifiers];
  }
}

- (void)listenToControlEvents
{
  // With this one as delegate, we would just listen to a keyboardChanged event, and remap the keyboard.
  // Like seriously remapping all keys anyway doesn't take that long, and you are in the settings of the app.
  // I separated it in different functions here because I really didn't want to regenerate everthing here and in the TV.
  // The other thing is that I can actually embed the info in the dictionary, and just redo here, instead of multiple events.
  // (But in the end those would have to be separate strings anyway, so it is pretty much the same).
  // And that was the thing, here we were mapping Defaults -> TC -> TV, even in the functions, and that doesn't make any sense anymore.
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(keyboardModifierChanged:)
                                               name:BKKeyboardModifierChanged
                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(keyboardCapsAsEscChanged:)
                                               name:BKKeyboardCapsAsEscChanged
                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(keyboardShiftAsEscChanged:)
                                               name:BKKeyboardShiftAsEscChanged
                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(keyboardFuncTriggerChanged:)
                                               name:BKKeyboardFuncTriggerChanged
                                             object:nil];
}

- (void)terminate
{
  // Disconnect message handler
  [_terminal.webView.configuration.userContentController removeScriptMessageHandlerForName:@"interOp"];

  [_session kill];
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  [_terminal loadTerminal];

  [self createPTY];
}

- (void)createPTY
{
  pipe(_pinput);
  _termout = fterm_open(_terminal, 0);
  _termerr = fterm_open(_terminal, 0);
  _termin = fdopen(_pinput[0], "r");
  _termsz = malloc(sizeof(struct winsize));
}

- (void)startSession
{
  // Until we are able to duplicate the streams, we have to recreate them.
  TermStream *stream = [[TermStream alloc] init];
  stream.in = _termin;
  stream.out = _termout;
  stream.err = _termerr;
  stream.control = self;
  stream.sz = _termsz;

  _session = [[MCPSession alloc] initWithStream:stream];
  _session.delegate = self;
  [_session executeWithArgs:@""];
}

//  Since ViewController is a WKScriptMessageHandler, as declared in the ViewController interface, it must implement the userContentController:didReceiveScriptMessage method. This is the method that is triggered each time 'interOp' is sent a message from the JavaScript code.
- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message
{
  NSDictionary *sentData = (NSDictionary *)message.body;
  NSString *operation = sentData[@"op"];
  NSDictionary *data = sentData[@"data"];

  if ([operation isEqualToString:@"sigwinch"]) {
    [self updateTermRows:data[@"rows"] Cols:data[@"columns"]];
  } else if ([operation isEqualToString:@"terminalready"]) {
    [self startSession];
  }
}

- (void)setRawMode:(BOOL)raw
{
  [_terminal setRawMode:raw];
}

- (BOOL)rawMode
{
  return [_terminal rawMode];
}

- (void)updateTermRows:(NSNumber *)rows Cols:(NSNumber *)cols
{
  _termsz->ws_row = rows.shortValue;
  _termsz->ws_col = cols.shortValue;
  [_session sigwinch];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
  if (_termin) {
    fclose(_termin);
    _termin = NULL;
  }
  if (_termout) {
    fclose(_termout);
    _termout = NULL;
  }
  if (_termerr) {
    fclose(_termerr);
    _termerr = NULL;
  }
  if (_termsz) {
    free(_termsz);
    _termsz = NULL;
  }
}

#pragma mark SessionDelegate

- (void)sessionFinished
{
  [_delegate terminalHangup:self];
}

#pragma mark Notifications

- (void)keyboardModifierChanged:(NSNotification *)notification
{
  // Map the sequence to a function in destination
  NSDictionary *action = [notification userInfo];
  [self assignSequence:action[@"sequence"] toModifier:[bkModifierMaps[action[@"modifier"]] integerValue]];
}

- (void)keyboardCapsAsEscChanged:(NSNotification *)notification
{
  if ([BKDefaults isCapsAsEsc]) {
    [_terminal assignKey:UIKeyInputEscape toModifier:UIKeyModifierAlphaShift];
  } else {
    [_terminal assignKey:nil toModifier:UIKeyModifierAlphaShift];
  }
}

- (void)keyboardShiftAsEscChanged:(NSNotification *)notification
{
  if ([BKDefaults isShiftAsEsc]) {
    [_terminal assignKey:UIKeyInputEscape toModifier:UIKeyModifierShift];
  } else {
    [_terminal assignKey:nil toModifier:UIKeyModifierShift];
  }
}

- (void)keyboardFuncTriggerChanged:(NSNotification *)notification
{
  NSDictionary *action = [notification userInfo];
  [self assignFunction:action[@"func"] toTriggers:action[@"trigger"]];
}

@end
