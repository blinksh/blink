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


@interface SpaceController () <UIPageViewControllerDataSource, UIPageViewControllerDelegate,
  UIGestureRecognizerDelegate, TermControlDelegate>

@property (readonly) TermController *currentTerm;

@end

@implementation SpaceController {
  UIPageViewController *_viewportsController;
  NSMutableArray *_viewports;
  
  UITapGestureRecognizer *_twoFingersTap;
  UIPanGestureRecognizer *_twoFingersDrag;
  
  NSLayoutConstraint *_topConstraint;
  NSLayoutConstraint *_bottomConstraint;
  
  UIPageControl *_pageControl;
  MBProgressHUD *_hud;

  NSMutableArray<UIKeyCommand *> *_kbdCommands;
  NSMutableArray<UIKeyCommand *> *_kbdCommandsWithoutDiscoverability;
}

#pragma mark Setup
- (void)loadView
{
  [super loadView];
  NSDictionary *options = [NSDictionary dictionaryWithObject:
					  [NSNumber numberWithInt:UIPageViewControllerSpineLocationMid]
						      forKey:UIPageViewControllerOptionSpineLocationKey];

  self.view.backgroundColor = [UIColor blackColor];
  self.view.opaque = YES;

  _viewportsController = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:options];
  _viewportsController.view.backgroundColor = [UIColor blackColor];
  _viewportsController.view.opaque = YES;
  _viewportsController.dataSource = self;
  _viewportsController.delegate = self;

  [self addChildViewController:_viewportsController];
  
  [self.view addSubview:_viewportsController.view];
  [_viewportsController didMoveToParentViewController:self];
  [_viewportsController.view setTranslatesAutoresizingMaskIntoConstraints:NO];

  // Support new top & bottom guides (and fixes the notch)
  if (@available(iOS 11, *)) {
    _topConstraint = [_viewportsController.view.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor];
    _bottomConstraint = [_viewportsController.view.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor];
  } else {
    _topConstraint = [_viewportsController.view.topAnchor constraintEqualToAnchor:self.view.topAnchor];
    _bottomConstraint = [_viewportsController.view.bottomAnchor constraintEqualToAnchor:self.bottomLayoutGuide.bottomAnchor];
  }
  
  // Container view fills out entire root view.
  [NSLayoutConstraint activateConstraints:
    @[
      _topConstraint,
      [_viewportsController.view.leftAnchor constraintEqualToAnchor:self.view.leftAnchor],
      [_viewportsController.view.rightAnchor constraintEqualToAnchor:self.view.rightAnchor],
      _bottomConstraint
      ]
   ];

  // Termination notification
  UIApplication *app = [UIApplication sharedApplication];
  [[NSNotificationCenter defaultCenter] addObserver:self
					   selector:@selector(applicationWillTerminate:)
					       name:UIApplicationWillTerminateNotification
					     object:app];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
  [_viewports enumerateObjectsUsingBlock:^(TermController *term, NSUInteger idx, BOOL * _Nonnull stop) {
    [term terminate];
  }];
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  if (_viewports == nil) {
    [self _createShellWithUserActivity: nil sessionStateKey:nil animated:NO completion:nil];
    [self setKbdCommands];
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

- (void)focusOnShell
{
  [self.currentTerm.terminal performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
  [super decodeRestorableStateWithCoder:coder];
  
  NSArray *sessionStateKeys = [coder decodeObjectForKey:@"sessionStateKeys"];
  
//  [[_viewports firstObject] terminate];
  _viewports = [[NSMutableArray alloc] init];
  
  for (NSString *sessionStateKey in sessionStateKeys) {
    TermController *term = [[TermController alloc] init];
    term.sessionStateKey = sessionStateKey;
    term.delegate = self;
    term.userActivity = nil;
    [_viewports addObject:term];
  }
  
  NSInteger idx = [coder decodeIntegerForKey:@"idx"];
  TermController *term = _viewports[idx];
  [_viewportsController setViewControllers:@[term] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
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
}

- (void)saveStates
{
  for (TermController * term in _viewports) {
    [term saveState];
  }
}

- (void)registerForNotifications
{
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  
  [defaultCenter removeObserver:self];

  [defaultCenter addObserver:self
                    selector:@selector(keyboardWasShown:)
                        name:UIKeyboardDidShowNotification
                      object:nil];
  
  [defaultCenter addObserver:self
                    selector:@selector(keyboardWillBeHidden:)
                        name:UIKeyboardWillHideNotification
                      object:nil];

  [defaultCenter addObserver:self
		    selector:@selector(keyboardFuncTriggerChanged:)
			name:BKKeyboardFuncTriggerChanged
		      object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  if (self.view.window.screen == [UIScreen mainScreen]) {
    [self addGestures];
    [self registerForNotifications];
  }
}

- (void)addGestures
{
  if (!_twoFingersTap) {
    _twoFingersTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTwoFingersTap:)];
    [_twoFingersTap setNumberOfTouchesRequired:2];
    [_twoFingersTap setNumberOfTapsRequired:1];
    _twoFingersTap.delegate = self;
    [self.view addGestureRecognizer:_twoFingersTap];
  }

  if (!_twoFingersDrag) {
    _twoFingersDrag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleTwoFingersDrag:)];
    [_twoFingersDrag setMinimumNumberOfTouches:2];
    [_twoFingersDrag setMaximumNumberOfTouches:2];
    _twoFingersDrag.delegate = self;
    [self.view addGestureRecognizer:_twoFingersDrag];
  }
}

#pragma mark Events
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(nonnull UIGestureRecognizer *)otherGestureRecognizer
{
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
- (void)keyboardWasShown:(NSNotification *)sender
{
  CGRect frame = [sender.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  CGRect newFrame = [self.view convertRect:frame fromView:[[UIApplication sharedApplication] delegate].window];
  _bottomConstraint.constant = newFrame.origin.y - CGRectGetHeight(self.view.frame) + self.bottomLayoutGuide.length;

  UIView *termAccessory = [self.currentTerm.terminal inputAccessoryView];
  if ([termAccessory isHidden]) {
    _bottomConstraint.constant += termAccessory.frame.size.height;
  }

  [self.view setNeedsUpdateConstraints];
}

- (void)keyboardWillBeHidden:(NSNotification *)aNotification
{
  _bottomConstraint.constant = 0;
  [self.view updateConstraintsIfNeeded];
  [self.view setNeedsUpdateConstraints];
}

- (void)handleTwoFingersTap:(UITapGestureRecognizer *)sender
{
  [self _createShellWithUserActivity: nil sessionStateKey: nil animated:YES completion:nil];
}

- (void)handleTwoFingersDrag:(UIPanGestureRecognizer *)sender
{
  CGFloat y = [sender translationInView:self.view].y;
  CGFloat height = self.view.frame.size.height;
  CGRect frame = self.view.frame;

  if (y > 0) {
    [self.view setFrame:CGRectMake(frame.origin.x, y, frame.size.width, frame.size.height)];
    _viewportsController.view.alpha = 1 - (y * 2/ height);
  }

  if (sender.state == UIGestureRecognizerStateEnded) {
    CGPoint velocity = [sender velocityInView:self.view];
    [self.view setFrame:CGRectMake(frame.origin.x, 0, frame.size.width, frame.size.height)];

    if (velocity.y > height * 2) {
      _viewportsController.view.alpha = 1;
      [self closeCurrentSpace];
    } else {
      _viewportsController.view.alpha = 1;
      // Rollback up animated
      [UIView animateWithDuration:0.25
                       animations:^{
                         [self.view layoutIfNeeded];
                       }];
    }
  }
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

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers transitionCompleted:(BOOL)completed
{
  if (completed) {
    [self displayHUD];
    [self focusOnShell];
  }
}

#pragma mark Spaces
- (TermController *)currentTerm {
  return _viewportsController.viewControllers[0];
}

- (UIPageControl *)pageControl
{
  if (!_pageControl) {
    _pageControl = [[UIPageControl alloc] init];
    _pageControl.currentPageIndicatorTintColor = [UIColor cyanColor];
  }

  _pageControl.numberOfPages = [_viewports count];

  return _pageControl;
}

- (void)displayHUD
{
  if (!_hud) {
    _hud = [[MBProgressHUD alloc] initWithView:self.view];
    _hud.mode = MBProgressHUDModeCustomView;
    _hud.bezelView.color = [UIColor darkGrayColor];
    _hud.contentColor = [UIColor whiteColor];
    [self.view addSubview:_hud];
  } else {
    // Add some tolerance before changing the center of the HUD.
    CGPoint newCenter = CGPointMake(_hud.center.x, self.currentTerm.terminal.frame.size.height/2);
    UIView *termAccessory = [self.currentTerm.terminal inputAccessoryView];
    if (fabs(_hud.center.y - newCenter.y) > termAccessory.frame.size.height) {
      [UIView animateWithDuration:0.25 animations:^{
        _hud.center = newCenter;
      }];
    }
  }

  _hud.userInteractionEnabled = NO;

  UIPageControl *pages = [self pageControl];

  NSInteger idx = [_viewports indexOfObject:self.currentTerm];
  NSString *title = self.currentTerm.terminal.title.length ? self.currentTerm.terminal.title : @"blink";
  NSString *geometry = [NSString stringWithFormat:@"%d x %d", self.currentTerm.terminal.rowCount, self.currentTerm.terminal.columnCount];

  _hud.label.numberOfLines = 2;
  _hud.label.text = [NSString stringWithFormat:@"%@\n%@", title, geometry];

  pages.currentPage = idx;
  _hud.customView = pages;

  [_hud showAnimated:NO];
  _hud.alpha = 0.6;

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
				    animated:NO
				  completion:^(BOOL didComplete) {
				    // Remove viewport from the list after animation
            if (didComplete) {
              [weakSelf displayHUD];
              [weakSelf focusOnShell];
				    }
				  }];
  } else {
    [_viewports removeObjectAtIndex:idx];
    [_viewportsController setViewControllers:@[ _viewports[idx] ]
				   direction:UIPageViewControllerNavigationDirectionForward
				    animated:NO
				  completion:^(BOOL didComplete) {
				    // Remove viewport from the list after animation
				    if (didComplete) {
		[weakSelf displayHUD];
		[weakSelf focusOnShell];
				    }
				  }];
  }
}

- (void)_createShellWithUserActivity:(NSUserActivity *) userActivity sessionStateKey:(NSString *)sessionStateKey animated:(BOOL)animated completion:(void (^)(BOOL finished))completion
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
				  if (completion) {
				    completion(didComplete);
				  }
				  if (didComplete) {
				    [weakSelf displayHUD];
				    // Still not in view hierarchy, so calling through selector. There should be a way...
				    [weakSelf focusOnShell];
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
  if ([control.view isFirstResponder]) {
    [self displayHUD];
  }
}

#pragma mark External Keyboard

- (NSArray<UIKeyCommand *> *)keyCommands
{
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
  [BKUserConfigurationManager shortCutModifierFlags];
  _kbdCommands = [[NSMutableArray alloc] initWithObjects:
   [UIKeyCommand keyCommandWithInput: @"t" modifierFlags: [BKUserConfigurationManager shortCutModifierFlags]
                              action: @selector(newShell:)
                discoverabilityTitle: @"New shell"],
   [UIKeyCommand keyCommandWithInput: @"w" modifierFlags: [BKUserConfigurationManager shortCutModifierFlags]
                              action: @selector(closeShell:)
                discoverabilityTitle: @"Close shell"],
   [UIKeyCommand keyCommandWithInput: @"]" modifierFlags: [BKUserConfigurationManager shortCutModifierFlags]
                              action: @selector(nextShell:)
                discoverabilityTitle: @"Next shell"],
   [UIKeyCommand keyCommandWithInput: @"[" modifierFlags: [BKUserConfigurationManager shortCutModifierFlags]
                              action: @selector(prevShell:)
                discoverabilityTitle: @"Previous shell"],

   [UIKeyCommand keyCommandWithInput: @"o" modifierFlags: [BKUserConfigurationManager shortCutModifierFlags]
                              action: @selector(otherScreen:)
                discoverabilityTitle: @"Other Screen"],
   [UIKeyCommand keyCommandWithInput: @"o" modifierFlags: [BKUserConfigurationManager shortCutModifierFlags]
                              action: @selector(moveToOtherScreen:)
                discoverabilityTitle: @"Move schell to other Screen"],
   [UIKeyCommand keyCommandWithInput: @"," modifierFlags: [BKUserConfigurationManager shortCutModifierFlags]
                              action: @selector(showConfig:)
                discoverabilityTitle: @"Show config"],
  nil];
  
  for (NSInteger i = 1; i < 11; i++) {
    NSInteger keyN = i % 10;
    NSString *input = [NSString stringWithFormat:@"%li", (long)keyN];
    NSString *title = [NSString stringWithFormat:@"Switch to shell %li", (long)i];
    UIKeyCommand * cmd = [UIKeyCommand keyCommandWithInput: input
                                             modifierFlags: [BKUserConfigurationManager shortCutModifierFlags]
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
    [self displayHUD];
    return;
  }
  
  UIViewController *ctrl = _viewports[idx];
  
  __weak typeof(self) weakSelf = self;
  [_viewportsController setViewControllers:@[ ctrl ]
				 direction:direction
				  animated:animated
				completion:^(BOOL didComplete) {
				  if (didComplete) {
				    [weakSelf displayHUD];
            [weakSelf focusOnShell];
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

  [self displayHUD];
}

- (void)moveCurrentShellFromSpaceController:(SpaceController *)spaceController
{
  TermController *term = spaceController.currentTerm;
  term.delegate = self;
  [_viewports addObject:term];
  [spaceController removeCurrentSpace];
  [self displayHUD];
}

- (void)viewScreenWillBecomeActive
{
  [self displayHUD];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
  // Fix for github issue #299
  // Even app is not in active state it still recieves actions like CMD+T and etc.
  // So we filter them here.
  
  UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
  
  if (appState != UIApplicationStateActive) {
    return NO;
  }
  
  return [super canPerformAction:action withSender:sender];
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
      [self focusOnShell];
    } else {
      [self _createShellWithUserActivity:activity sessionStateKey:nil animated:YES completion:nil];
    }
    return;
  }

  // 3. We are already showing required term. So do nothing.
  if (idx == targetIdx) {
    [self focusOnShell];
    return;
  }

  // 4. Switch to found term index.
  UIPageViewControllerNavigationDirection direction =
  idx < targetIdx ? UIPageViewControllerNavigationDirectionForward : UIPageViewControllerNavigationDirectionReverse;

  [self switchShellIdx: targetIdx
             direction: direction
              animated: NO];
}

- (void)suspend
{
  [_viewports enumerateObjectsUsingBlock:^(TermController *term, NSUInteger idx, BOOL * _Nonnull stop) {
    [term suspend];
  }];
}

- (void)resume
{
  [_viewports enumerateObjectsUsingBlock:^(TermController *term, NSUInteger idx, BOOL * _Nonnull stop) {
    [term resume];
  }];
}


@end
