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
#import "StateManager.h"
#import "TermView.h"


NSString * const BKUserActivityTypeCommandLine = @"com.blink.cmdline";
NSString * const BKUserActivityCommandLineKey = @"com.blink.cmdline.key";


@interface TermController () <SessionDelegate, TermDeviceDelegate>
@end

@implementation TermController {
  NSDictionary *_activityUserInfo;
  MCPSession *_session;
  NSInteger _fontSizeBeforeScaling;
  TermDevice *_termDevice;
  TermView *_termView;
}

- (void)loadView
{
  [super loadView];
  
  if (_sessionStateKey == nil) {
    _sessionStateKey = [[NSProcessInfo processInfo] globallyUniqueString];
  }
  
  _termDevice = [[TermDevice alloc] init];
  _termDevice.delegate = self;
  
  _termView = [[TermView alloc] initWithFrame:self.view.bounds andBgColor: self.bgColor];
  _termView.restorationIdentifier = @"TermView";
  [_termDevice attachView:_termView];
  
  self.view = _termView;
}

- (NSString *)title {
  return _termDevice.view.title;
}

- (void)indexCommand:(NSString *)cmdLine {
  
  NSUserActivity * activity = [[NSUserActivity alloc] initWithActivityType:BKUserActivityTypeCommandLine];
  activity.eligibleForPublicIndexing = NO;
  activity.eligibleForSearch = YES;
  activity.eligibleForHandoff = YES;
  
  if (@available(iOS 12.0, *)) {
    activity.eligibleForPrediction = YES;
  }
  
  
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

- (bool)canRestoreUserActivityState:(NSUserActivity *)activity {
  return ![_session isRunningCmd] || [activity.title isEqualToString:self.activityKey];
}

- (bool)isRunningCmd {
  return [_session isRunningCmd];
}

- (void)restoreUserActivityState:(NSUserActivity *)activity
{
  [super restoreUserActivityState:activity];
  
  if (![activity.activityType isEqualToString: BKUserActivityTypeCommandLine]) {
    return;
  }
  
  NSString *cmdLine = [activity.userInfo objectForKey:BKUserActivityCommandLineKey];
  
  if ([_session isRunningCmd] || !cmdLine) {
    return;
  }
  char ctrlA = 'a' - 'a' + 1;
  char ctrlK = 'k' - 'a' + 1;
  // delete all input on current line - ctrl+a ctrl+k
  // run command
  if (self.userActivity) {
    [_termDevice write:[NSString stringWithFormat:@"%c%c%@\n", ctrlA, ctrlK, cmdLine]];
  } else {
    self.userActivity = activity;
  }
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  if (_sessionParameters == nil) {
    [self _initSessionParameters];
  }

  [_termView loadWith:_sessionParameters];
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

- (void)startSession
{
  TermInput *input = _termDevice.input;
  _termDevice = [[TermDevice alloc] init];
  _termDevice->win.ws_col = _sessionParameters.cols;
  _termDevice->win.ws_row = _sessionParameters.rows;
  
  _termDevice.delegate = self;

  [_termDevice attachView:_termView];
  [_termDevice attachInput:input];

  _session = [[MCPSession alloc] initWithDevice:_termDevice andParametes:_sessionParameters];
  _session.delegate = self;
  [_session executeWithArgs:@""];
}


- (void)dealloc
{
  [_termDevice attachView:nil];
  _termDevice = nil;
  _session.device = nil;
  _session = nil;
  [self.userActivity resignCurrent];
}

#pragma mark SessionDelegate

- (void)sessionFinished
{
  [_delegate terminalHangup:self];
}

#pragma mark - TermDeviceDelegate

- (void)deviceIsReady
{
  [self startSession];
  if (self.userActivity) {
    [self restoreUserActivityState:self.userActivity];
  }
}

- (void)deviceSizeChanged
{
  _sessionParameters.rows = _termDevice->win.ws_row;
  _sessionParameters.cols = _termDevice->win.ws_col;
  
  if ([self.delegate respondsToSelector:@selector(terminalDidResize:)]) {
    [self.delegate terminalDidResize:self];
  }
  [_session sigwinch];
}

- (void)viewFontSizeChanged:(NSInteger)newSize
{
  _sessionParameters.fontSize = newSize;
  [_termDevice.input reset];
}
  
- (BOOL)handleControl:(NSString *)control
{
  return [_session handleControl:control];
}
  
- (void)deviceFocused
{
  return [_session setActiveSession];
}

- (UIViewController *)viewController
{
  return self;
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
}

#pragma mark Notifications


- (void)terminate
{
  [_termView terminate];
  [_session kill];
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

  [self startSession];
  
  if (self.view.bounds.size.width != _sessionParameters.viewWidth ||
      self.view.bounds.size.height != _sessionParameters.viewHeight) {
    [_session sigwinch];
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
      break;
    }
    default:
      break;
  }
}

@end
