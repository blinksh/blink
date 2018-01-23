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

#import "SpaceController.h"
#import "BKDefaults.h"
#import "BKSettingsNotifications.h"
#import "BKUserConfigurationManager.h"
#import "MBProgressHUD/MBProgressHUD.h"
#import "ScreenController.h"
#import "SmartKeysController.h"
#import "TermController.h"
#import "TermInput.h"
#import "MusicManager.h"


@interface SpaceController () <UIPageViewControllerDataSource, UIPageViewControllerDelegate,
  UIGestureRecognizerDelegate, TermControlDelegate>

@property (readonly) TermController *currentTerm;

@end

@implementation SpaceController {
  UIPageViewController *_viewportsController;
  NSMutableArray *_viewports;
  
  UITapGestureRecognizer *_twoFingersTap;
  UIPanGestureRecognizer *_twoFingersDrag;
  
  MBProgressHUD *_hud;
  MBProgressHUD *_musicHUD;

  NSMutableArray<UIKeyCommand *> *_kbdCommands;
  NSMutableArray<UIKeyCommand *> *_kbdCommandsWithoutDiscoverability;
  UIEdgeInsets _rootLayoutMargins;
  TermInput *_termInput;
  BOOL _unfocused;
}

#pragma mark Setup
- (void)loadView
{
  [super loadView];
  
  _termInput = [[TermInput alloc] init];
  [self.view addSubview:_termInput];
  
  self.view.opaque = YES;
  
  NSDictionary *options = [NSDictionary dictionaryWithObject:
                           [NSNumber numberWithInt:UIPageViewControllerSpineLocationMid]
                                            forKey:UIPageViewControllerOptionSpineLocationKey];

  _viewportsController = [[UIPageViewController alloc]
                          initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                          navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                          options:options];
  _viewportsController.view.opaque = YES;
  _viewportsController.dataSource = self;
  _viewportsController.delegate = self;
  
  [self addChildViewController:_viewportsController];
  _viewportsController.view.layoutMargins = UIEdgeInsetsZero;
  _viewportsController.view.frame = self.view.bounds;
  [self.view addSubview:_viewportsController.view];
  [_viewportsController didMoveToParentViewController:self];
  
  [self registerForNotifications];
}

- (void)viewWillLayoutSubviews
{
  [super viewWillLayoutSubviews];
  
  CGRect rect = self.view.bounds;
  
  if (@available(iOS 11.0, *)) {
    UIEdgeInsets insets = self.view.safeAreaInsets;
    insets.bottom = MAX(_rootLayoutMargins.bottom, insets.bottom);
    if (insets.bottom == 0) {
      insets.bottom = 1;
    }
    rect = UIEdgeInsetsInsetRect(rect, insets);
  } else {
    rect = UIEdgeInsetsInsetRect(rect, _rootLayoutMargins);
  }
  
  _viewportsController.view.frame = rect;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  [self setKbdCommands];
  if (_viewports == nil) {
    [self _createShellWithUserActivity: nil sessionStateKey:nil animated:YES completion:nil];
  }
}

- (BOOL)canBecomeFirstResponder
{
  return YES;
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}

- (void)_attachInputToCurrentTerm
{
  [self.currentTerm attachInput:_termInput];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder andStateManager: (StateManager *)stateManager
{
  _unfocused = [coder decodeBoolForKey:@"_infocused"];
  NSArray *sessionStateKeys = [coder decodeObjectForKey:@"sessionStateKeys"];
  
  _viewports = [[NSMutableArray alloc] init];
  
  for (NSString *sessionStateKey in sessionStateKeys) {
    TermController *term = [[TermController alloc] init];
    term.sessionStateKey = sessionStateKey;
    [stateManager restoreState:term];
    term.delegate = self;
    term.userActivity = nil;
    
    [_viewports addObject:term];
  }
  
  NSInteger idx = [coder decodeIntegerForKey:@"idx"];
  TermController *term = _viewports[idx];
  
  [self loadViewIfNeeded];
  
  __weak typeof(self) weakSelf = self;
  [_viewportsController setViewControllers:@[term]
                                 direction:UIPageViewControllerNavigationDirectionForward
                                  animated:NO
                                completion:^(BOOL complete) {
                                  if (complete) {
                                    [weakSelf _attachInputToCurrentTerm];
                                  }
                                }];
  [self.view setNeedsLayout];
  [self.view layoutIfNeeded];
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
  [super encodeRestorableStateWithCoder:coder];
  NSMutableArray *sessionStateKeys = [[NSMutableArray alloc] init];
  
  for (TermController *term in _viewports) {
    [sessionStateKeys addObject:term.sessionStateKey];
  }
  
  NSInteger idx = [_viewports indexOfObject:self.currentTerm];
  if(idx == NSNotFound) {
    idx = 0;
  }
  [coder encodeInteger:idx forKey:@"idx"];
  [coder encodeObject:sessionStateKeys forKey:@"sessionStateKeys"];
  [coder encodeBool:_unfocused forKey:@"_infocused"];
}

- (void)registerForNotifications
{
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  
  [defaultCenter removeObserver:self];

  [defaultCenter addObserver:self
                    selector:@selector(_keyboardWillChangeFrame:)
                        name:UIKeyboardWillChangeFrameNotification
                      object:nil];
  
  [defaultCenter addObserver:self
                    selector:@selector(_appDidBecomeActive)
                        name:UIApplicationDidBecomeActiveNotification
                      object:nil];
  
  [defaultCenter addObserver:self
                    selector:@selector(_appWillResignActive)
                        name:UIApplicationWillResignActiveNotification
                      object:nil];
  
  
  [defaultCenter addObserver:self
		    selector:@selector(keyboardFuncTriggerChanged:)
			name:BKKeyboardFuncTriggerChanged
		      object:nil];
}

- (void)_appDidBecomeActive
{
  if ([_termInput isFirstResponder]) {
    [self _attachInputToCurrentTerm];
    return;
  }

  if (!_unfocused) {
    [_termInput becomeFirstResponder];
    [self _attachInputToCurrentTerm];
  }
}

-(void)_appWillResignActive
{
  _unfocused = ![_termInput isFirstResponder];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  if (self.view.window.screen == [UIScreen mainScreen]) {
    [self addGestures];
  }
}

- (void)addGestures
{
  if (!_twoFingersTap) {
    _twoFingersTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleTwoFingersTap:)];
    [_twoFingersTap setNumberOfTouchesRequired:2];
    [_twoFingersTap setNumberOfTapsRequired:1];
    _twoFingersTap.delegate = self;
    [self.view addGestureRecognizer:_twoFingersTap];
  }

  if (!_twoFingersDrag) {
    _twoFingersDrag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_handleTwoFingersDrag:)];
    [_twoFingersDrag setMinimumNumberOfTouches:2];
    [_twoFingersDrag setMaximumNumberOfTouches:2];
    _twoFingersDrag.delegate = self;
    _twoFingersDrag.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:_twoFingersDrag];
  }
}

#pragma mark Events
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(nonnull UIGestureRecognizer *)otherGestureRecognizer
{
  if (gestureRecognizer == _twoFingersTap && otherGestureRecognizer == _twoFingersDrag) {
    return YES;
  }
  if (gestureRecognizer == _twoFingersTap && [otherGestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
    return YES;
  }
  return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
  if (gestureRecognizer == _twoFingersDrag && ![otherGestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
    return YES;
  }

  return NO;
}

// The Space will be responsible to accommodate the work environment for widgets, adjusting the size, making sure it doesn't overlap content,
// moving widgets or scrolling to them when necessary, etc...
// In this case we make sure we take the SmartBar/Keys into account.
- (void)_keyboardWillChangeFrame:(NSNotification *)sender
{
  CGFloat bottomInset = 0;
  
  CGRect kbFrame = [sender.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  
  CGFloat viewHeight = CGRectGetHeight(self.view.bounds);
  if (CGRectGetMaxY(kbFrame) >= viewHeight) {
    bottomInset = viewHeight - kbFrame.origin.y;
  }
  
  UIView *accessoryView = _termInput.inputAccessoryView;
  CGFloat accessoryHeight = accessoryView.frame.size.height;
  
  if (bottomInset > accessoryHeight) {
    accessoryView.hidden = NO;
  } else if (bottomInset == accessoryHeight) {
    if ([self.currentTerm.termView isDragging]) {
      accessoryView.hidden = YES;
    } else {
      accessoryView.hidden = ![BKUserConfigurationManager userSettingsValueForKey:BKUserConfigShowSmartKeysWithXKeyBoard];
    }
  } else if (kbFrame.size.height == 0) { // Other screen kb
    accessoryView.hidden = YES;
  }
  
  if (accessoryView.hidden) {
    bottomInset -= accessoryHeight;
  }
  
  if (_rootLayoutMargins.bottom != bottomInset) {
    _rootLayoutMargins.bottom = bottomInset;
    
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
  }
}

- (void)_handleTwoFingersTap:(UITapGestureRecognizer *)sender
{
  if (sender.state == UIGestureRecognizerStateRecognized) {
    [self _createShellWithUserActivity: nil sessionStateKey: nil animated:YES completion:nil];
  }
}

- (CGAffineTransform)_transformForTranslation:(CGPoint)translation {
  
  CGFloat scale = 0.5;//MAX(MIN(1 - (-translation.y * 3/ height), 0.5), 0.3);
  
  CGAffineTransform move = CGAffineTransformMakeScale(scale, scale);
  return CGAffineTransformTranslate(move, translation.x, translation.y);
}

- (void)_setAnimationState:(TermView *)termView on:(BOOL)on {
  [termView setFreezed:on];
  if (on) {
    termView.layer.shadowColor = [UIColor whiteColor].CGColor;
    termView.layer.shadowOffset = CGSizeMake(0, 20);
    termView.layer.shadowOpacity = 0.7;
    termView.layer.shadowRadius = 40;
    
  } else {
    termView.layer.shadowColor = [UIColor whiteColor].CGColor;
    termView.layer.shadowOffset = CGSizeMake(0, 0);
    termView.layer.shadowOpacity = 0;
    termView.layer.shadowRadius = 0;
    termView.alpha = 1;
  }
}

- (void)_handleTwoFingersDrag:(UIPanGestureRecognizer *)sender
{
  TermView *v = self.currentTerm.termView;
  CGPoint t = [sender translationInView:self.view];
  
  if (sender.state == UIGestureRecognizerStateBegan) {
    [self _setAnimationState:v on:YES];
  
    [UIView animateWithDuration:0.5
                          delay:0
         usingSpringWithDamping:0.7
          initialSpringVelocity:1.0
                        options:kNilOptions
                     animations:^{
       v.transform = [self _transformForTranslation:t];
       
    } completion:nil];
  }
  
  if (sender.state == UIGestureRecognizerStateChanged) {
    if (ABS(t.y) > _viewportsController.view.bounds.size.height * 0.25) {
      if (!v.readyToDelete) {
        [v setReadyToDelete:YES];
      }
    } else {
      if (v.readyToDelete) {
        [v setReadyToDelete:NO];
      }
    }
    v.transform = [self _transformForTranslation:t];
  }
  
  if (sender.state == UIGestureRecognizerStateCancelled) {
    v.readyToDelete = NO;
    v.transform = CGAffineTransformIdentity;
    [self _setAnimationState:v on: NO];
    [UIView animateWithDuration:0.5
                          delay:0
         usingSpringWithDamping:0.6
          initialSpringVelocity:1.0
                        options:kNilOptions
                     animations:^{
                       v.transform = CGAffineTransformIdentity;
                     } completion:nil];
  }
  
  if (sender.state == UIGestureRecognizerStateEnded) {
    if (v.readyToDelete) {
      CGAffineTransform transform =  CGAffineTransformScale(CGAffineTransformTranslate(v.transform, 0, -self.view.bounds.size.height), 0.4, 0.4);
    [UIView animateWithDuration:0.4
                          delay:0
         usingSpringWithDamping:0.9
          initialSpringVelocity:1.0
                        options:kNilOptions
                     animations:^{
                       v.transform = transform;
                     } completion:^(BOOL complete){
                          [self _setAnimationState:v on: NO];
                          v.alpha = 0;
                          [self closeCurrentSpace];
                     }];
      return;
    }
    [self _setAnimationState:v on: NO];
    v.readyToDelete = NO;
  
    [UIView animateWithDuration:0.5
                          delay:0
         usingSpringWithDamping:0.6
          initialSpringVelocity:1.0
                        options:kNilOptions
                     animations:^{
        v.transform = CGAffineTransformIdentity;
    } completion:nil];
  }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer == _twoFingersDrag) {
    return [_twoFingersDrag translationInView:self.view].y < 0;
  }
  
  return YES;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController
{
  if (nil == viewController) {
    return _viewports[0];
  }
  NSInteger idx = [_viewports indexOfObject:viewController];

  if (idx >= [_viewports count] - 1) {
    return nil;
  }
  return _viewports[idx + 1];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
      viewControllerBeforeViewController:(UIViewController *)viewController
{
  if (nil == viewController) {
    return _viewports[0];
  }
  NSInteger idx = [_viewports indexOfObject:viewController];

  if (idx <= 0) {
    return nil;
  }
  return _viewports[idx - 1];
}

- (void)pageViewController:(UIPageViewController *)pageViewController
        didFinishAnimating:(BOOL)finished
   previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers
       transitionCompleted:(BOOL)completed
{
  if (completed) {
    for (TermController *term in previousViewControllers) {
      [term attachInput:nil];
    }

    [self _displayHUD];
    [self _attachInputToCurrentTerm];
  }
}


#pragma mark Spaces
- (TermController *)currentTerm {
  return _viewportsController.viewControllers[0];
}

- (void)_toggleMusicHUD
{
  if (_musicHUD) {
    [_musicHUD hideAnimated:YES];
    _musicHUD = nil;
    [[MusicManager shared] onHide];
    return;
  }

  [_hud hideAnimated:NO];

  _musicHUD = [MBProgressHUD showHUDAddedTo:_viewportsController.view animated:YES];
  _musicHUD.mode = MBProgressHUDModeCustomView;
  _musicHUD.bezelView.color = [UIColor darkGrayColor];
  _musicHUD.contentColor = [UIColor whiteColor];
  [_musicHUD setMargin: 0];
  [[MusicManager shared] onShow];
  _musicHUD.customView = [[MusicManager shared] hudView];
  
  UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_toggleMusicHUD)];
  [_musicHUD.backgroundView addGestureRecognizer:tapRecognizer];
}

- (void)_displayHUD
{
  if (_musicHUD) {
    [_musicHUD hideAnimated:YES];
    _musicHUD = nil;
    return;
  }
  
  if (_hud) {
    [_hud hideAnimated:NO];
  }

  _hud = [MBProgressHUD showHUDAddedTo:_viewportsController.view animated:_hud == nil];
  _hud.mode = MBProgressHUDModeCustomView;
  _hud.bezelView.color = [UIColor darkGrayColor];
  _hud.contentColor = [UIColor whiteColor];
  _hud.userInteractionEnabled = NO;
  _hud.alpha = 0.6;
  
  UIPageControl *pages = [[UIPageControl alloc] init];
  pages.currentPageIndicatorTintColor = [UIColor cyanColor];
  pages.numberOfPages = [_viewports count];
  pages.currentPage = [_viewports indexOfObject:self.currentTerm];
  
  _hud.customView = pages;
  
  NSString *title = self.currentTerm.title.length ? self.currentTerm.title : @"blink";
  
  MCPSessionParameters *params = self.currentTerm.sessionParameters;
  if (params.rows == 0 && params.cols == 0) {
    _hud.label.numberOfLines = 1;
    _hud.label.text = title;
  } else {
    NSString *geometry =
      [NSString stringWithFormat:@"%ld x %ld", (long)params.rows, (long)params.cols];

    _hud.label.numberOfLines = 2;
    _hud.label.text = [NSString stringWithFormat:@"%@\n%@", title, geometry];
  }

  [_hud hideAnimated:YES afterDelay:1.f];
}

- (void)closeCurrentSpace
{
  [self.currentTerm terminate];
  [self removeCurrentSpace];
}

- (void)removeCurrentSpace {
  
  NSInteger idx = [_viewports indexOfObject:self.currentTerm];
  if(idx == NSNotFound) {
    return;
  }

  NSInteger numViewports = [_viewports count];

  __weak typeof(self) weakSelf = self;
  if (idx == 0 && numViewports == 1) {
    // Only one viewport. Create a new one to replace this
    [_viewports removeObjectAtIndex:0];
    [self _createShellWithUserActivity: nil sessionStateKey:nil animated:NO completion:nil];
  } else if (idx >= [_viewports count] - 1) {
    // Last viewport, go to the previous.
    [_viewports removeLastObject];
    [_viewportsController setViewControllers:@[ _viewports[idx - 1] ]
				   direction:UIPageViewControllerNavigationDirectionReverse
				    animated:YES
				  completion:^(BOOL didComplete) {
				    // Remove viewport from the list after animation
            if (didComplete) {
              [weakSelf _displayHUD];
              [weakSelf _attachInputToCurrentTerm];
            }
				  }];
  } else {
    [_viewports removeObjectAtIndex:idx];
    [_viewportsController setViewControllers:@[ _viewports[idx] ]
				   direction:UIPageViewControllerNavigationDirectionForward
				    animated:YES
				  completion:^(BOOL didComplete) {
				    // Remove viewport from the list after animation
				    if (didComplete) {
              [weakSelf _displayHUD];
              [weakSelf _attachInputToCurrentTerm];
				    }
				  }];
  }
}

- (void)_createShellWithUserActivity:(NSUserActivity *) userActivity
                     sessionStateKey:(NSString *)sessionStateKey
                            animated:(BOOL)animated
                          completion:(void (^)(BOOL finished))completion
{
  TermController *term = [[TermController alloc] init];
  term.sessionStateKey = sessionStateKey;
  term.delegate = self;
  term.userActivity = userActivity;

  if (_viewports == nil) {
    _viewports = [[NSMutableArray alloc] init];
  }
  NSInteger numViewports = [_viewports count];

  if (numViewports == 0) {
    [_viewports addObject:term];
  } else {
    NSInteger idx = [_viewports indexOfObject:self.currentTerm];
    if (idx == numViewports - 1) {
      // If it is the last one, insert there.
      [_viewports addObject:term];
    } else {
      // Insert next to the current terminal.
      [_viewports insertObject:term atIndex:idx + 1];
    }
  }

  __weak typeof(self) weakSelf = self;
  [_viewportsController setViewControllers:@[ term ]
				 direction:UIPageViewControllerNavigationDirectionForward
				  animated:animated
				completion:^(BOOL didComplete) {
				  if (didComplete) {
            [weakSelf _displayHUD];
            [weakSelf _attachInputToCurrentTerm];
				  }
          if (completion) {
            completion(didComplete);
          }
				}];
}

#pragma mark TermControlDelegate

- (void)terminalHangup:(TermController *)control
{
  // Close the Space if the terminal finishing is the current one.
  if (self.currentTerm == control) {
    [self closeCurrentSpace];
  }
}

- (void)terminalDidResize:(TermController*)control
{
  [self _displayHUD];
}

#pragma mark External Keyboard

- (NSArray<UIKeyCommand *> *)keyCommands
{
  if (_musicHUD) {
    return [[MusicManager shared] keyCommands];
  }

  NSMutableDictionary *kbMapping = [NSMutableDictionary dictionaryWithDictionary:[BKDefaults keyboardMapping]];
  if([kbMapping objectForKey:@"⌘ Cmd"] && ![[kbMapping objectForKey:@"⌘ Cmd"]isEqualToString:@"None"]){
    return _kbdCommandsWithoutDiscoverability;
  }
  return _kbdCommands;
}

- (void)keyboardFuncTriggerChanged:(NSNotification *)notification
{
  NSDictionary *action = [notification userInfo];
  if ([action[@"func"] isEqual:BKKeyboardFuncShortcutTriggers]) {
    [self setKbdCommands];
  }
}

- (void)setKbdCommands
{
  UIKeyModifierFlags modifierFlags = [BKUserConfigurationManager shortCutModifierFlags];
  
  _kbdCommands = [[NSMutableArray alloc] initWithObjects:
   [UIKeyCommand keyCommandWithInput: @"t" modifierFlags:modifierFlags
                              action: @selector(newShell:)
                discoverabilityTitle: @"New shell"],
   [UIKeyCommand keyCommandWithInput: @"w" modifierFlags: modifierFlags
                              action: @selector(closeShell:)
                discoverabilityTitle: @"Close shell"],
   [UIKeyCommand keyCommandWithInput: @"]" modifierFlags: modifierFlags
                              action: @selector(nextShell:)
                discoverabilityTitle: @"Next shell"],
   [UIKeyCommand keyCommandWithInput: @"[" modifierFlags: modifierFlags
                              action: @selector(prevShell:)
                discoverabilityTitle: @"Previous shell"],

   [UIKeyCommand keyCommandWithInput: @"o" modifierFlags: modifierFlags
                              action: @selector(otherScreen:)
                discoverabilityTitle: @"Other Screen"],
   [UIKeyCommand keyCommandWithInput: @"o" modifierFlags: modifierFlags
                              action: @selector(moveToOtherScreen:)
                discoverabilityTitle: @"Move schell to other Screen"],
   [UIKeyCommand keyCommandWithInput: @"," modifierFlags: modifierFlags
                              action: @selector(showConfig:)
                discoverabilityTitle: @"Show config"],
                  
    [UIKeyCommand keyCommandWithInput: @"m" modifierFlags: modifierFlags
                               action: @selector(_toggleMusicHUD)
                 discoverabilityTitle: @"Music Controls"],
                  
    [UIKeyCommand keyCommandWithInput:@"+"
                        modifierFlags:modifierFlags
                               action:@selector(_increaseFontSize:)
                 discoverabilityTitle:@"Zoom In"],
    [UIKeyCommand keyCommandWithInput:@"-"
                        modifierFlags:modifierFlags
                               action:@selector(_decreaseFontSize:)
                 discoverabilityTitle:@"Zoom Out"],
    [UIKeyCommand keyCommandWithInput:@"="
                        modifierFlags:modifierFlags
                               action:@selector(_resetFontSize:)
                 discoverabilityTitle:@"Reset Zoom"],
  nil];
  
  for (NSInteger i = 1; i < 11; i++) {
    NSInteger keyN = i % 10;
    NSString *input = [NSString stringWithFormat:@"%li", (long)keyN];
    NSString *title = [NSString stringWithFormat:@"Switch to shell %li", (long)i];
    UIKeyCommand * cmd = [UIKeyCommand keyCommandWithInput: input
                                             modifierFlags: modifierFlags
                                                    action: @selector(switchToShellN:)
                                      discoverabilityTitle: title];
    
    [_kbdCommands addObject:cmd];
  }
  
  for (UIKeyCommand *command in _kbdCommands) {
    UIKeyCommand *commandWithoutDiscoverability = [command copy];
    commandWithoutDiscoverability.discoverabilityTitle = nil;
    [_kbdCommandsWithoutDiscoverability addObject:commandWithoutDiscoverability];
  }
  
}

- (void)_increaseFontSize:(UIKeyCommand *)cmd
{
  [self.currentTerm.termView increaseFontSize];
}

- (void)_decreaseFontSize:(UIKeyCommand *)cmd
{
  [self.currentTerm.termView decreaseFontSize];
}

- (void)_resetFontSize:(UIKeyCommand *)cmd
{
  [self.currentTerm.termView resetFontSize];
}

- (void)playNext:(UIKeyCommand *)cmd
{
//  [[MPMusicPlayerController systemMusicPlayer] skipToNextItem];
}

- (void)playPrev:(UIKeyCommand *)cmd
{
//  [[MPMusicPlayerController systemMusicPlayer] skipToBeginning];
}

- (void)otherScreen:(UIKeyCommand *)cmd
{
  [[ScreenController shared] switchToOtherScreen];
}

- (void)newShell:(UIKeyCommand *)cmd
{
  [self _createShellWithUserActivity: nil sessionStateKey:nil animated:YES completion:nil];
}

- (void)closeShell:(UIKeyCommand *)cmd
{
  [self closeCurrentSpace];
}

- (void)moveToOtherScreen:(UIKeyCommand *)cmd
{
  [[ScreenController shared] moveCurrentShellToOtherScreen];
}

- (void)showConfig:(UIKeyCommand *)cmd 
{
  UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Settings" bundle:nil];
  UINavigationController *vc = [sb instantiateViewControllerWithIdentifier:@"NavSettingsController"];

  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    UIViewController *rootVC = ScreenController.shared.mainScreenRootViewController;
    [rootVC presentViewController:vc animated:YES completion:NULL];
  }];
}

- (void)switchShellIdx:(NSInteger)idx direction:(UIPageViewControllerNavigationDirection)direction animated:(BOOL) animated
{
  if (idx < 0 || idx >= _viewports.count) {
    [self _displayHUD];
    return;
  }
  
  UIViewController *ctrl = _viewports[idx];
  
  __weak typeof(self) weakSelf = self;
  [_viewportsController setViewControllers:@[ ctrl ]
				 direction:direction
				  animated:animated
				completion:^(BOOL didComplete) {
          if (didComplete) {
            [weakSelf _displayHUD];
            [weakSelf _attachInputToCurrentTerm];
          }
				}];
}

- (void)nextShell:(UIKeyCommand *)cmd
{
  NSInteger idx = [_viewports indexOfObject:self.currentTerm];
  if(idx == NSNotFound) {
    return;
  }
 
  [self switchShellIdx: idx + 1
             direction: UIPageViewControllerNavigationDirectionForward
              animated: YES];
}

- (void)prevShell:(UIKeyCommand *)cmd
{
  NSInteger idx = [_viewports indexOfObject:self.currentTerm];
  if(idx == NSNotFound) {
    return;
  }
 
  [self switchShellIdx: idx - 1
             direction: UIPageViewControllerNavigationDirectionReverse
              animated: YES];
}

- (void)switchToShellN:(UIKeyCommand *)cmd
{
  NSInteger targetIdx = [cmd.input integerValue];
  if (targetIdx <= 0) {
    targetIdx = 10;
  }
  
  targetIdx -= 1;
  [self switchToTargetIndex:targetIdx];
}

- (void)switchToTargetIndex:(NSInteger)targetIdx
{
  NSInteger idx = [_viewports indexOfObject:self.currentTerm];
  if(idx == NSNotFound) {
    return;
  }
  
  if (idx == targetIdx) {
    // We are on this page already.
    return;
  }

  UIPageViewControllerNavigationDirection direction =
    idx < targetIdx ? UIPageViewControllerNavigationDirectionForward : UIPageViewControllerNavigationDirectionReverse;
  
  
  [self switchShellIdx: targetIdx
             direction: direction
              animated: YES];
}

# pragma moving spaces

- (void)moveAllShellsFromSpaceController:(SpaceController *)spaceController
{
  for (TermController *ctrl in spaceController->_viewports) {
    ctrl.delegate = self;
    [_viewports addObject:ctrl];
  }

  [self _displayHUD];
}

- (void)moveCurrentShellFromSpaceController:(SpaceController *)spaceController
{
  TermController *term = spaceController.currentTerm;
  term.delegate = self;
  [_viewports addObject:term];
  [spaceController removeCurrentSpace];
  [self _displayHUD];
}

- (void)viewScreenWillBecomeActive
{
  [self _displayHUD];
  [_termInput becomeFirstResponder];
}

- (void)viewScreenDidBecomeInactive
{
  [_termInput resignFirstResponder];
}

- (void)restoreUserActivityState:(NSUserActivity *)activity
{
  // somehow we don't have current term... so we just create new one
  NSInteger idx = [_viewports indexOfObject:self.currentTerm];
  if(idx == NSNotFound) {
    [self _createShellWithUserActivity:activity sessionStateKey:nil animated:YES completion:nil];
    return;
  }

  // 1. Try find term with same activity key
  NSInteger targetIdx = [_viewports indexOfObjectPassingTest:^BOOL(TermController *term, NSUInteger idx, BOOL * _Nonnull stop) {
    return [activity.title isEqualToString:term.activityKey];
  }];

  // 2. No term with same activity key, so we create one or use current
  if (targetIdx == NSNotFound) {
    if (self.currentTerm.activityKey == nil) {
      [self.currentTerm restoreUserActivityState:activity];
      [self _attachInputToCurrentTerm];
    } else {
      [self _createShellWithUserActivity:activity sessionStateKey:nil animated:YES completion:nil];
    }
    return;
  }

  // 3. We are already showing required term. So do nothing.
  if (idx == targetIdx) {
    [self _attachInputToCurrentTerm];
    return;
  }

  // 4. Switch to found term index.
  UIPageViewControllerNavigationDirection direction =
  idx < targetIdx ? UIPageViewControllerNavigationDirectionForward : UIPageViewControllerNavigationDirectionReverse;

  [self switchShellIdx: targetIdx
             direction: direction
              animated: NO];
}

- (void)suspendWith:(StateManager *) stateManager
{
  for (TermController * term in _viewports) {
    [term suspend];
    [stateManager snapshotState:term];
  }
}

- (void)resumeWith:(StateManager *)stateManager
{
  for (TermController * term in _viewports) {
    [stateManager restoreState:term];
    [term resume];
  };
}

- (void)musicCommand:(UIKeyCommand *)cmd
{
  [[MusicManager shared] handleCommand:cmd];
  [self _toggleMusicHUD];
}


@end
