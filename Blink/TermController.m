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
#import "MCPSession.h"
#import "Session.h"
#import "fterm.h"


@interface TermController () <WKScriptMessageHandler, TerminalDelegate, SessionDelegate>
@end

@implementation TermController {
  int _pinput[2];
  MCPSession *_session;
  BOOL _viewIsLocked;
}

- (void)write:(NSString *)input
{
  // Trasform the string and write it, with the correct sequence
  const char *str = [input UTF8String];
  write(_pinput[1], str, strlen(str));
}

- (void)loadView
{
  [super loadView];
  WKWebViewConfiguration *theConfiguration = [[WKWebViewConfiguration alloc] init];
  [theConfiguration.userContentController addScriptMessageHandler:self name:@"interOp"];
  _terminal = [[TerminalView alloc] initWithFrame:self.view.frame configuration:theConfiguration];
  _terminal.delegate = self;

  self.view = _terminal;
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

@end
