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
#import "MBProgressHUD/MBProgressHUD.h"
#import "SmartKeys.h"
#import "TermController.h"


@interface SpaceController () <UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, readonly) UIPageViewController *viewportsController;
@property (nonatomic, readonly) NSMutableArray *viewports;
@property (readonly) TermController *currentTerm;

@end

@implementation SpaceController {
  NSLayoutConstraint *bottomConstraint;
  NSLayoutConstraint *_topConstraint;
  UIPageControl *_pageControl;
  MBProgressHUD *_hud;
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


  // Container view fills out entire root view.
  _topConstraint = [NSLayoutConstraint constraintWithItem:_viewportsController.view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1 constant:0];
  [self.view addConstraint:_topConstraint];
  [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_viewportsController.view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
  [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_viewportsController.view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeRight multiplier:1 constant:0]];
  self->bottomConstraint = [NSLayoutConstraint constraintWithItem:_viewportsController.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.bottomLayoutGuide attribute:NSLayoutAttributeTop multiplier:1 constant:0];
  [self.view addConstraint:self->bottomConstraint];
  
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
  [self createShellAnimated:NO completion:nil];
  [self addGestures];
  [self registerForKeyboardNotifications];
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}

- (void)registerForKeyboardNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
					   selector:@selector(keyboardWasShown:)
					       name:UIKeyboardDidShowNotification
					     object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
					   selector:@selector(keyboardWillBeHidden:)
					       name:UIKeyboardWillHideNotification
					     object:nil];
}

- (void)addGestures
{
  UITapGestureRecognizer *twoFingersTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTwoFingersTap:)];
  [twoFingersTap setNumberOfTouchesRequired:2];
  [twoFingersTap setNumberOfTapsRequired:1];
  [self.view addGestureRecognizer:twoFingersTap];

  UIPanGestureRecognizer *twoFingersDrag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleTwoFingersDrag:)];
  [twoFingersDrag setMinimumNumberOfTouches:2];
  [twoFingersDrag setMaximumNumberOfTouches:2];
  twoFingersDrag.delegate = self;
  [self.view addGestureRecognizer:twoFingersDrag];
}

#pragma mark Events
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
  if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]] && [otherGestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
    [gestureRecognizer requireGestureRecognizerToFail: otherGestureRecognizer];
    
    return NO;
  }
  return YES;
}

// The Space will be responsible to accommodate the work environment for widgets, adjusting the size, making sure it doesn't overlap content,
// moving widgets or scrolling to them when necessary, etc...
// In this case we make sure we take the SmartBar/Keys into account.
- (void)keyboardWasShown:(NSNotification *)sender
{
  CGRect frame = [sender.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  CGRect newFrame = [self.view convertRect:frame fromView:[[UIApplication sharedApplication] delegate].window];
  self->bottomConstraint.constant = newFrame.origin.y - CGRectGetHeight(self.view.frame);

  UIView *termAccessory = [self.currentTerm.terminal inputAccessoryView];
  if ([termAccessory isHidden]) {
    self->bottomConstraint.constant += termAccessory.frame.size.height;
  }

  [self.view setNeedsUpdateConstraints];
}
- (void)keyboardWillBeHidden:(NSNotification *)aNotification
{
  self->bottomConstraint.constant = 0;
  [self.view updateConstraintsIfNeeded];
  [self.view setNeedsUpdateConstraints];
}

- (void)handleTwoFingersTap:(UITapGestureRecognizer *)sender
{
  [self createShellAnimated:YES completion:nil];
}

- (void)handleTwoFingersDrag:(UIPanGestureRecognizer *)sender
{
  CGFloat y = [sender translationInView:self.view].y;
  if (y > 0) {
    _topConstraint.constant = y;
    _viewportsController.view.alpha = 1 - (y / 100);
  }
  if (sender.state == UIGestureRecognizerStateEnded) {
    CGPoint velocity = [sender velocityInView:self.view];
    if (velocity.y > 100) {
      _viewportsController.view.alpha = 1;
      _topConstraint.constant = 0;
      [self.view layoutIfNeeded];
      [self closeCurrentSpace];
    } else {
      _topConstraint.constant = 0;
      _viewportsController.view.alpha = 1;
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
  NSParameterAssert(idx != NSNotFound);
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
  NSParameterAssert(idx != NSNotFound);

  if (idx <= 0) {
    return nil;
  }

  return _viewports[idx - 1];
}

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers transitionCompleted:(BOOL)completed
{
  if (completed) {
    [self displayHUD];
    [self.currentTerm.terminal performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0];
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
  }

  _hud.userInteractionEnabled = NO;

  UIPageControl *pages = [self pageControl];

  NSInteger idx = [_viewports indexOfObject:self.currentTerm];
  NSString *title = self.currentTerm.terminal.title;
  if (title.length == 0) {
    title = @"blink";
  }

  _hud.label.text = title;


  pages.currentPage = idx;
  _hud.customView = pages;

  [_hud showAnimated:YES];
  _hud.alpha = 0.6;

  [_hud hideAnimated:YES afterDelay:1.f];
}

- (void)closeCurrentSpace
{
  NSInteger idx = [_viewports indexOfObject:self.currentTerm];

  NSInteger numViewports = [_viewports count];
  
  [self.currentTerm terminate];

  __weak typeof(self) weakSelf = self;
  if (idx == 0 && numViewports == 1) {
    // Only one viewport. Create a new one to replace this
    [self createShellAnimated:NO
		   completion:^(BOOL didComplete) {
		     [weakSelf.viewports removeObjectAtIndex:0];
		   }];
  } else if (idx >= [_viewports count] - 1) {
    // Last viewport, go to the previous
    [_viewportsController setViewControllers:@[ _viewports[idx - 1] ]
				   direction:UIPageViewControllerNavigationDirectionReverse
				    animated:YES
				  completion:^(BOOL didComplete) {
				    // Remove viewport from the list after animation
				    if (didComplete) {
				      [weakSelf.viewports removeLastObject];
				      [weakSelf displayHUD];
				      [weakSelf.currentTerm.terminal performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0];
				    }
				  }];
  } else {
    [_viewportsController setViewControllers:@[ _viewports[idx + 1] ]
				   direction:UIPageViewControllerNavigationDirectionForward
				    animated:YES
				  completion:^(BOOL didComplete) {
				    // Remove viewport from the list after animation
				    if (didComplete) {
				      [weakSelf.viewports removeObjectAtIndex:idx];
				      [weakSelf displayHUD];
				      [weakSelf.currentTerm.terminal performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0];
				    }
				  }];
  }
}

- (void)createShellAnimated:(BOOL)animated completion:(void (^)(BOOL finished))completion
{
  TermController *term = [[TermController alloc] init];

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
				    [weakSelf.currentTerm.terminal performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0];
				  }
				}];
}

@end
