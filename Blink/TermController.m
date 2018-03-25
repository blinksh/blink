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

#import "TermController.h"
#import "BKDefaults.h"
#import "BKSettingsNotifications.h"
#import "MCPSession.h"
#import "Session.h"
#import "fterm.h"
#import "StateManager.h"

NSString * const BKUserActivityTypeCommandLine = @"com.blink.cmdline";
NSString * const BKUserActivityCommandLineKey = @"com.blink.cmdline.key";


@interface TermController () <TerminalDelegate, SessionDelegate>
@end

@implementation TermController {
  int _pinput[2];
  MCPSession *_session;
  NSDictionary *_activityUserInfo;
  BOOL _isReloading;
  NSInteger _fontSizeBeforeScaling;
}

- (void)loadView
{
  [super loadView];
  
  if (_sessionStateKey == nil) {
    _sessionStateKey = [[NSProcessInfo processInfo] globallyUniqueString];
  }
  
  _termView = [[TermView alloc] initWithFrame:self.view.frame];
  _termView.restorationIdentifier = @"TermView";
  _termView.termDelegate = self;
  
  self.view = _termView;
}

- (NSString *)title {
  return _termView.title;
}

- (void)write:(NSString *)input
{
  // Trasform the string and write it, with the correct sequence
  const char *str = [input UTF8String];
  write(_pinput[1], str, [input lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
}

- (BOOL)handleControl:(NSString *)control
{
  return [_session handleControl:control];
}

- (void)indexCommand:(NSString *)cmdLine {
  
  NSUserActivity * activity = [[NSUserActivity alloc] initWithActivityType:BKUserActivityTypeCommandLine];
  activity.eligibleForPublicIndexing = NO;
  activity.eligibleForSearch = YES;
  activity.eligibleForHandoff = YES;
  
  
  _activityKey = [NSString stringWithFormat:@"run: %@ ", cmdLine];
  [activity setTitle:_activityKey];
  
  _activityUserInfo = @{BKUserActivityCommandLineKey: cmdLine ?: @"help"};
  
  activity.userInfo = _activityUserInfo;
  
  self.userActivity = activity;
  [self.userActivity becomeCurrent];
}

- (void)updateUserActivityState:(NSUserActivity *)activity
{
  [activity setTitle:_activityKey];
  [activity addUserInfoEntriesFromDictionary:_activityUserInfo];
  activity.keywords = [NSSet setWithArray:@[@"blink", @"shell", @"mosh", @"ssh", @"terminal", @"remote"]];
  
  [activity setRequiredUserInfoKeys:[NSSet setWithArray:_activityUserInfo.allKeys]];
}

- (void)restoreUserActivityState:(NSUserActivity *)activity
{
  if (![activity.activityType isEqualToString: BKUserActivityTypeCommandLine]) {
    [super restoreUserActivityState:activity];
  }
  
  NSString *cmdLine = [activity.userInfo objectForKey:BKUserActivityCommandLineKey];
  if (cmdLine) {
    // TODO: investigate lost first char on iPad
    [self write:[NSString stringWithFormat:@" %@\n", cmdLine]];
  }
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  if (_sessionParameters == nil) {
    [self _initSessionParameters];
  }

  [_termView loadWith:_sessionParameters];

  [self createPTY];
}

- (void)_initSessionParameters
{
  _sessionParameters = [[MCPSessionParameters alloc] init];
  _sessionParameters.fontSize = [[BKDefaults selectedFontSize] integerValue];
  _sessionParameters.fontName = [BKDefaults selectedFontName];
  _sessionParameters.themeName = [BKDefaults selectedThemeName];
  _sessionParameters.enableBold = [BKDefaults enableBold];
  _sessionParameters.boldAsBright = [BKDefaults isBoldAsBright];
  _sessionParameters.viewWidth = self.view.bounds.size.width;
  _sessionParameters.viewHeight = self.view.bounds.size.height;
}

- (void)createPTY
{
  pipe(_pinput);
  _termout = fterm_open(_termView, 0);
  _termerr = fterm_open(_termView, 0);
  _termin = fdopen(_pinput[0], "r");
  _termsz = malloc(sizeof(struct winsize));
  _termsz->ws_col = _sessionParameters.cols;
  _termsz->ws_row = _sessionParameters.rows;
}

- (void)destroyPTY
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

- (void)startSession
{
  // Until we are able to duplicate the streams, we have to recreate them.
  TermStream *stream = [[TermStream alloc] init];
  stream.in = _termin;
  stream.out = _termout;
  stream.err = _termerr;
  stream.control = self;
  stream.sz = _termsz;

  _session = [[MCPSession alloc] initWithStream:stream andParametes:_sessionParameters];
  _session.delegate = self;
  [_session setActiveSession];
  [_session executeWithArgs:@""];
}

- (void)setRawMode:(BOOL)raw
{
  _rawMode = raw;
  _termInput.raw = raw;
}

- (void)updateTermRows:(NSNumber *)rows Cols:(NSNumber *)cols
{
  _termsz->ws_row = rows.shortValue;
  _termsz->ws_col = cols.shortValue;

  _sessionParameters.rows = rows.shortValue;
  _sessionParameters.cols = cols.shortValue;
  
  if ([self.delegate respondsToSelector:@selector(terminalDidResize:)]) {
    [self.delegate terminalDidResize:self];
  }
  [_session sigwinch];
}

- (void)fontSizeChanged:(NSNumber *)newSize
{
  _sessionParameters.fontSize = [newSize integerValue];
  [_termInput reset];
}

- (void)terminalIsReady: (NSDictionary *)data
{
  NSDictionary *size = data[@"size"];
  _sessionParameters.rows = [size[@"rows"] integerValue];
  _sessionParameters.cols = [size[@"cols"] integerValue];

  _termsz->ws_row = _sessionParameters.rows;
  _termsz->ws_col = _sessionParameters.cols;
  
  NSArray *bgColor = data[@"bgColor"];
  if (bgColor && bgColor.count == 3) {
    self.view.backgroundColor = [UIColor colorWithRed:[bgColor[0] floatValue] / 255.0f
                                                green:[bgColor[1] floatValue] / 255.0f
                                                 blue:[bgColor[2] floatValue] / 255.0f
                                                alpha:1];
  }
  
  [self startSession];
  if (self.userActivity) {
    [self restoreUserActivityState:self.userActivity];
  }
}

- (void)dealloc
{
  [self destroyPTY];
  
  [self.userActivity resignCurrent];
}

#pragma mark SessionDelegate

- (void)sessionFinished
{
  if (_isReloading) {
    _isReloading = NO;
    [self destroyPTY];
    [self createPTY];
    [self _initSessionParameters];
    [_termView reloadWith:_sessionParameters];
  } else {
    [_delegate terminalHangup:self];
  }
}

#pragma mark Notifications


- (void)terminate
{
  [_termView terminate];
  [_session kill];
}

- (void)reload
{
  _sessionParameters.childSessionType = nil;
  _sessionParameters.childSessionParameters =  nil;
  _isReloading = YES;
}

- (void)suspend
{
  [_sessionParameters cleanEncodedState];
  
  _sessionParameters.viewWidth = self.view.bounds.size.width;
  _sessionParameters.viewHeight = self.view.bounds.size.height;
  
  [_session suspend];
}

- (void)resume
{
  if (![_sessionParameters hasEncodedState]) {
    return;
  }

  [self destroyPTY];
  [self createPTY];
  [self startSession];
  
  if (self.view.bounds.size.width != _sessionParameters.viewWidth ||
      self.view.bounds.size.height != _sessionParameters.viewHeight) {
    [_session sigwinch];
  }
}

- (void)focus {
  [_termView focus];
  [_session setActiveSession];
  if (![_termView.window isKeyWindow]) {
    [_termView.window makeKeyWindow];
  }
  if (![_termInput isFirstResponder]) {
    [_termInput becomeFirstResponder];
  }
}

- (void)blur {
  [_termView blur];
}

- (void)attachInput:(TermInput *)termInput
{
  _termInput = termInput;
  if (!termInput) {
    [_termView blur];
  }

  if (_termInput.termDelegate != self) {
    [_termInput.termDelegate attachInput:nil];
    [_termInput reset];
  }

  _termInput.raw = _rawMode;
  _termInput.termDelegate = self;
  
  if ([_termInput isFirstResponder]) {
    [_termView focus];
    [_session setActiveSession]; 
  } else {
    [_termView blur];
  }
}

- (void)scaleWithPich:(UIPinchGestureRecognizer *)pinch
{
  switch (pinch.state) {
    case UIGestureRecognizerStateBegan:
    case UIGestureRecognizerStateEnded:
      _fontSizeBeforeScaling = _sessionParameters.fontSize;
      break;
    case UIGestureRecognizerStateChanged: {
      NSInteger newSize = (NSInteger)round(_fontSizeBeforeScaling * pinch.scale);
      if (newSize != _sessionParameters.fontSize) {
        [_termView setFontSize:@(newSize)];
      }
    }
    default:
      break;
  }
}

@end
