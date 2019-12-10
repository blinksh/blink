//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2019 Blink Mobile Shell Project
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


#import "KBWebViewBase.h"

@interface KeyCommand: UIKeyCommand
@end

@implementation KeyCommand {
  SEL _up;
}

- (void)setUp:(SEL) action {
  _up = action;
}

- (SEL)upAction {
  return _up;
}

@end

@interface KBWebViewBase (WKScriptMessageHandler) <WKScriptMessageHandler>
@end

@implementation KBWebViewBase {
  NSArray<UIKeyCommand *> *_keyCommands;
  NSString *_jsPath;
  NSString *_interopName;
  
  KeyCommand *_activeModsCommand;
  NSArray<KeyCommand *> *_imeGuardCommands;
  NSArray<KeyCommand *> *_activeIMEGuardCommands;
}

- (KeyCommand *)_modifiersCommand:(UIKeyModifierFlags) flags {
  KeyCommand *cmd = [KeyCommand keyCommandWithInput:@"" modifierFlags:flags action:@selector(_keyDown:)];
  [cmd setUp: @selector(_keyUp:)];
  return cmd;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    _keyCommands = @[];
    _jsPath = @"_onKB";
    _interopName = @"_kb";
    [self.configuration.userContentController addScriptMessageHandler:self name:_interopName];
    self.configuration.defaultWebpagePreferences.preferredContentMode = WKContentModeDesktop;
//    [self.configuration.preferences setJavaScriptCanOpenWindowsAutomatically:true];
    NSMutableArray *imeGuards = [[NSMutableArray alloc] init];
    
    // do we need guard - ` ?
    // alt+letter                ´     ¨     ˆ     ˜
    for (NSString * input in @[@"e", @"u", @"i", @"n"]) {
      KeyCommand *cmd = [KeyCommand keyCommandWithInput:input modifierFlags:UIKeyModifierAlternate action:@selector(_imeGuardDown:)];
      [cmd setUp:@selector(_imeGuardUp:)];
      [imeGuards addObject:cmd];
    }
    
    _activeIMEGuardCommands = nil;
    _imeGuardCommands = [imeGuards copy];
  }
  return self;
}

//- (BOOL)_requiresKeyboardWhenFirstResponder {
//  return YES;
//}
//
//- (BOOL)_requiresKeyboardResetOnReload {
//  return NO;
//}

- (BOOL)_becomeFirstResponderWhenPossible {
  return YES;
}

- (void)_keyboardDidChangeFrame:(NSNotification *)notification
{
}

- (void)_keyboardWillChangeFrame:(NSNotification *)notification
{
}

- (void)_keyboardWillShow:(NSNotification *)notification
{
}

- (void)_keyboardWillHide:(NSNotification *)notification
{
}

- (void)_keyboardDidHide:(NSNotification *)notification
{
}

- (void)_keyboardDidShow:(NSNotification *)notification
{
}




- (void)dealloc {
  [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)setHasSelection:(BOOL)value {
  [self report:@"selection" arg:value ? @"true" : @"false"];
}

- (void)reportLang:(NSString *) lang {
  [self report:@"lang" arg:[NSString stringWithFormat:@"\"%@\"", lang]];
}

- (void)_keyDown:(KeyCommand *)cmd {
  [self report:@"mods-down" arg:@(cmd.modifierFlags)];
}

- (void)_keyUp:(KeyCommand *)cmd {
  [self report:@"mods-up" arg:@(cmd.modifierFlags)];
}

- (void)reportStateReset {
  [self report:@"state-reset" arg: @""];
}

- (void)reportToolbarModifierFlags:(UIKeyModifierFlags)flags {
  [self report:@"toolbar-mods" arg:@(flags)];
}

- (void)reportKeyPress:(UIKeyModifierFlags)mods keyId:(NSString *)keyId {
  NSString *kid = [keyId stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
  [self report:@"toolbar-press" arg:[NSString stringWithFormat:@"\"%ld:%@\"", (long)mods, kid]];
}

// Not sure we need up
- (void)_imeGuardUp:(KeyCommand *)cmd {
  [self report:@"guard-up" arg:[NSString stringWithFormat:@"\"%@\"", cmd.input]];
}

- (void)_imeGuardDown:(KeyCommand *)cmd {
  [self report:@"guard-down" arg:[NSString stringWithFormat:@"\"%@\"", cmd.input]];
}

- (id)_inputDelegate { return self; }
- (int)_webView:(WKWebView *)webView decidePolicyForFocusedElement:(id) info { return 1; }

- (BOOL)becomeFirstResponder {
  BOOL res = [super becomeFirstResponder];
  [self report:@"focus" arg:res ? @"true" : @"false"];
  return res;
}

- (BOOL)resignFirstResponder {
  BOOL res = [super resignFirstResponder];
  // leave textfield focused
  // [self report:@"focus" arg: res ? @"false" : @"true"];
  return res;
}

- (void)setCaptureMode:(BOOL)value {
  [self report:@"capture" arg: value ? @"true" : @"false"];
}

- (void)onCapture:(NSArray<NSString *> *)keys {
  
}

- (void)onSelection:(NSDictionary *)args {
  
}

- (void)report:(NSString *)cmd arg:(NSObject *)arg {
  NSString *js = [NSString stringWithFormat:@"%@(\"%@\", %@);", _jsPath, cmd, arg];
  [self evaluateJavaScript:js completionHandler:nil];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
  if (@selector(toggleBoldface:) == action ||
      @selector(toggleItalics:) == action ||
      @selector(cut:) == action ||
      @selector(toggleFontPanel:) == action ||
      @selector(select:) == action ||
      @selector(selectAll:) == action ||
      @selector(toggleUnderline:) == action) {
    return NO;
  }

  return [super canPerformAction:action withSender:sender];
}

- (NSArray<UIKeyCommand *> *)keyCommands {
  return _keyCommands;
}

- (void)onIME:(NSString *)event data:(NSString *)data {
  
}

- (void)_onVoice:(NSString *)event data:(NSString *)data {
  
}

- (void)onOut:(NSString *)data {
  
}

- (void)onCommand:(NSString *)command {
  
}

- (void)_rebuildKeyCommands {
  NSMutableArray *cmds = [[NSMutableArray alloc] init];
  if (_activeModsCommand) {
    [cmds addObject:_activeModsCommand];
  }
  
  if (_activeIMEGuardCommands) {
    [cmds addObjectsFromArray:_activeIMEGuardCommands];
  }
  
  _keyCommands = cmds;
}

- (void)ready {
  [self removeAssistantsFromView];
}

- (void)removeAssistantsFromView {
  [self _removeAssistantsFromView:self];
}

- (void)_removeAssistantsFromView:(UIView *)view {
  view.inputAssistantItem.trailingBarButtonGroups = @[];
  view.inputAssistantItem.leadingBarButtonGroups = @[];
  
  for (UIView * v in view.subviews) {
    [self _removeAssistantsFromView:v];
  }
}


- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {

  if (![_interopName isEqual: message.name]) {
    return;
  }
  
  NSDictionary *body = message.body;
  NSString *op = body[@"op"];
  if (!op) {
    return;
  }
  
  if ([@"out" isEqual:op]) {
    NSString *data = body[@"data"];
    dispatch_async(dispatch_get_main_queue(), ^{
      [self onOut:data];
    });
  } else if ([@"mods" isEqual:op]) {
    NSNumber *mods = body[@"mods"];
    UIKeyModifierFlags flags = (UIKeyModifierFlags)mods.integerValue;
    if (flags == 0) {
      _activeModsCommand = nil;
    } else {
      _activeModsCommand = [self _modifiersCommand:flags];
    }
    [self _rebuildKeyCommands];
  } else if ([@"ime" isEqual:op]) {
    NSString *event = body[@"type"];
    NSString *data = body[@"data"];
    [self onIME:event data: data];
  } else if ([@"guard-ime-on" isEqual:op]) {
    if (_activeIMEGuardCommands == nil) {
      _activeIMEGuardCommands = _imeGuardCommands;
      [self _rebuildKeyCommands];
    }
  } else if ([@"guard-ime-off" isEqual:op]) {
    if (_activeIMEGuardCommands) {
      _activeIMEGuardCommands = nil;
      [self _rebuildKeyCommands];
    }
  } else if ([@"voice" isEqual:op]) {
    NSString *event = body[@"event"];
    NSString *data = body[@"data"];
    [self _onVoice:event data: data];
  } else if ([@"ready" isEqual: op]) {
    [self ready];
  } else if ([@"command" isEqual:op]) {
    [self onCommand: body[@"command"]];
  } else if ([@"selection" isEqual:op]) {
    [self onSelection:body];
  } else if([@"capture" isEqual: op]) {
    NSArray<NSString *> *keys = body[@"keys"];
    [self onCapture:keys];
  }
}

@end
