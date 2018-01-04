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
#import "BKFont.h"
#import "BKTheme.h"
#import "MCPSession.h"
#import "Session.h"
#import "fterm.h"
#import "StateManager.h"

NSString * const BKUserActivityTypeCommandLine = @"com.blink.cmdline";
NSString * const BKUserActivityCommandLineKey = @"com.blink.cmdline.key";

static NSDictionary *bkModifierMaps = nil;

@interface TermController () <TerminalDelegate, SessionDelegate>
@end

@implementation TermController {
  int _pinput[2];
  MCPSession *_session;
  BOOL _viewIsLocked;
  BOOL _appearanceChanged;
  BOOL _disableFontSizeSelection;
  NSDictionary *_activityUserInfo;
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
  
  if (_sessionStateKey == nil) {
    _sessionStateKey = [[NSProcessInfo processInfo] globallyUniqueString];
  }

  _terminal = [[TermView alloc] initWithFrame:self.view.frame];
  _terminal.restorationIdentifier = @"TermView";
  _terminal.delegate = self;

  self.view = _terminal;

  [self configureTerminal];
  [self listenToControlEvents];
}

- (void)configureTerminal
{
  [_terminal resetDefaultControlKeys];
  
  if ([BKDefaults autoRepeatKeys]) {
    [_terminal assignSequence:TermViewAutoRepeateSeq toModifier:0];
  }

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
  
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];

  [defaultCenter addObserver:self
                    selector:@selector(keyboardConfigChanged:)
                        name:BKKeyboardConfigChanged
                      object:nil];

  [defaultCenter addObserver:self
                    selector:@selector(keyboardConfigChanged:)
                        name:BKKeyboardFuncTriggerChanged
                      object:nil];

  [defaultCenter addObserver:self
                    selector:@selector(appearanceChanged:)
                        name:BKAppearanceChanged
                      object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
  if (_appearanceChanged) {
    [self setAppearanceFromSettings];
  }
  [super viewDidAppear:animated];
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

- (void)setAppearanceFromSettings
{
  // Load theme
  BKTheme *theme = [BKTheme withName:[BKDefaults selectedThemeName]];
  if (theme) {
    [_terminal loadTerminalThemeJS:theme.content];
  }

  BKFont *font = [BKFont withName:[BKDefaults selectedFontName]];
  if (font) {
    if (font.isCustom) {
      [_terminal loadTerminalFont:font.name cssFontContent:font.content];
    } else {
      [_terminal loadTerminalFont:font.name fromCSS:font.fullPath];
    }
  }

  if (!_disableFontSizeSelection) {
    NSNumber *fontSize = [BKDefaults selectedFontSize];
    [_terminal setFontSize:fontSize];
  }
  
  [_terminal setCursorBlink:[BKDefaults isCursorBlink]];

  [_terminal reset];
}


- (void)viewDidLoad
{
  [super viewDidLoad];
  
  if (_sessionParameters == nil) {
    _sessionParameters = [[MCPSessionParameters alloc] init];
  }

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
  [_session executeWithArgs:@""];
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
  _sessionParameters.rows = rows.shortValue;
  _sessionParameters.cols = cols.shortValue;
  
  if ([self.delegate respondsToSelector:@selector(terminalDidResize:)]) {
    [self.delegate terminalDidResize:self];
  }
  [_session sigwinch];
}

- (void)fontSizeChanged:(NSNumber *)newSize
{
  // Ignore the font size settings in case it was manually changed
  if (!([newSize isEqualToNumber:[BKDefaults selectedFontSize]])) {
    _disableFontSizeSelection = YES;
  }
}

- (void)terminalIsReady
{
  [self setAppearanceFromSettings];
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
  [_delegate terminalHangup:self];
}

#pragma mark Notifications

- (void)keyboardConfigChanged:(NSNotification *)notification
{
  [self configureTerminal];
}

- (void)appearanceChanged:(NSNotification *)notification
{
  if (self.isViewLoaded && self.view.window) {
    [self setAppearanceFromSettings];
  } else {
    _appearanceChanged = YES;
  }
}

- (void)terminate
{
  // Disconnect message handler
  [_terminal.webView.configuration.userContentController removeScriptMessageHandlerForName:@"interOp"];
  
  [_session kill];
}

- (void)suspend
{
  [_session suspend];
}

- (void)resume
{
  [self destroyPTY];
  [self createPTY];
  [self startSession];
}

@end
