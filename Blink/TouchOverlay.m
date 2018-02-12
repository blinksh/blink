//
//  TouchOverlay.m
//  Blink
//
//  Created by Yury Korolev on 1/29/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import "TouchOverlay.h"


const CGFloat kToolBarHeight = 82;

@interface TouchOverlay () <UIGestureRecognizerDelegate, UIScrollViewDelegate>
@end

@implementation TouchOverlay
{
  
  UITapGestureRecognizer *_twoFingerTapGestureRecognizer;
  UIPinchGestureRecognizer *_pinchGestureRecognizer;
  UILongPressGestureRecognizer *_longPressGestureRecognizer;
  
  UIScrollView *_pagedScrollView;
  
  ControlPanel *_controlPanel;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    
    self.decelerationRate = UIScrollViewDecelerationRateFast;
    
    // Interactive dismiss keyboard
    self.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.showsVerticalScrollIndicator = NO;
    self.showsHorizontalScrollIndicator = NO;
    
    self.alwaysBounceVertical = NO;
    self.alwaysBounceHorizontal = NO;
    self.delaysContentTouches = NO;
    
    self.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    
    // We want only two fingers
    self.panGestureRecognizer.minimumNumberOfTouches = 2;
    self.panGestureRecognizer.maximumNumberOfTouches = 2;
    
    _oneFingerTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleOneFingerTap:)];
    _oneFingerTapGestureRecognizer.numberOfTouchesRequired = 1;
    _oneFingerTapGestureRecognizer.delegate = self;
    
    _twoFingerTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleTwoFingerTap:)];
    _twoFingerTapGestureRecognizer.numberOfTapsRequired = 1;
    _twoFingerTapGestureRecognizer.numberOfTouchesRequired = 2;
    _twoFingerTapGestureRecognizer.delegate = self;
    
    _pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(_handlePinch:)];
    _pinchGestureRecognizer.delegate = self;
    
    // The goal of this gesture recognizer is two guard long press selection.
    _longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_handleLongPress:)];
    _longPressGestureRecognizer.numberOfTouchesRequired = 1;
    _longPressGestureRecognizer.delegate = self;
    [_oneFingerTapGestureRecognizer requireGestureRecognizerToFail:_longPressGestureRecognizer];
    
    
    
    _controlPanel = [[ControlPanel alloc] initWithFrame:self.bounds];
    [self addSubview:_controlPanel];
    self.delegate = self;
  }
  
  return self;
}

- (void)_resetOtherInteractions
{
  // Make recognizers and scroll view to forget of their current touches
  _oneFingerTapGestureRecognizer.enabled = NO;
  _twoFingerTapGestureRecognizer.enabled = NO;
  _longPressGestureRecognizer.enabled = NO;
  
  _pagedScrollView.scrollEnabled = NO;
  
  
  _oneFingerTapGestureRecognizer.enabled = YES;
  _twoFingerTapGestureRecognizer.enabled = YES;
  _longPressGestureRecognizer.enabled = YES;
  
  _pagedScrollView.scrollEnabled = YES;
}

- (void)attachPageViewController:(UIPageViewController *)ctrl
{
  // Need to find that scrollview
  if ([ctrl.view.subviews.firstObject isKindOfClass:[UIScrollView class]]) {
    _pagedScrollView = (UIScrollView *)ctrl.view.subviews.firstObject;
  } else {
    _pagedScrollView = nil;
  }
}


- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
  // We pass hit test to super view.
  UIView *res = [super hitTest:point withEvent:event];
  
  if (res == self) {
    return nil;
  }
  
  return res;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  self.contentSize = CGSizeMake(self.bounds.size.width, self.bounds.size.height + kToolBarHeight);
  _controlPanel.frame = CGRectMake(0, self.contentSize.height - kToolBarHeight, self.bounds.size.width, kToolBarHeight);
}

- (void)didMoveToSuperview
{
  if (self.superview) {
    [self.superview addGestureRecognizer:self.panGestureRecognizer];
    [self.superview addGestureRecognizer:_oneFingerTapGestureRecognizer];
    [self.superview addGestureRecognizer:_twoFingerTapGestureRecognizer];
    [self.superview addGestureRecognizer:_pinchGestureRecognizer];
    [self.superview addGestureRecognizer:_longPressGestureRecognizer];
  }
}

- (void)_handleLongPress:(UILongPressGestureRecognizer *)recognizer
{
  
}

- (void)_handleOneFingerTap:(UITapGestureRecognizer *)recognizer
{
  if (recognizer.state == UIGestureRecognizerStateRecognized) {
    [_touchDelegate touchOverlay:self onOneFingerTap:recognizer];
  }
}

- (void)_handleTwoFingerTap:(UITapGestureRecognizer *)recognizer
{
  if (recognizer.state == UIGestureRecognizerStateRecognized) {
    [_touchDelegate touchOverlay:self onTwoFingerTap:recognizer];
  }
}

- (void)_handlePinch:(UIPinchGestureRecognizer *)recognizer
{
  [_touchDelegate touchOverlay:self onPinch:recognizer];
  
  if (recognizer.state == UIGestureRecognizerStatePossible) {
    return;
  }
  
  CGFloat scale = recognizer.scale;
  if (scale < 0.95 || scale >= 1.05) {
    [self _resetOtherInteractions];
    self.scrollEnabled = NO;
    self.scrollEnabled = YES;
  }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
  // Determine which table cell the scrolling will stop on.
  NSInteger cellIndex = floor(targetContentOffset->y / kToolBarHeight);
  
  // Round to the next cell if the scrolling will stop over halfway to the next cell.
  if ((targetContentOffset->y - (floor(targetContentOffset->y / kToolBarHeight) * kToolBarHeight)) > kToolBarHeight) {
    cellIndex++;
  }
  
  // Adjust stopping point to exact beginning of cell.
  targetContentOffset->y = cellIndex * kToolBarHeight;
}

- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView
{
  // The NO / YES process makes it forget about previous events and avoids collisions.
  _pinchGestureRecognizer.enabled = NO;
  _pinchGestureRecognizer.enabled = YES;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
  // The NO / YES process makes it forget about previous events and avoids collisions.
  _pinchGestureRecognizer.enabled = NO;
  _pinchGestureRecognizer.enabled = YES;
  [self _resetOtherInteractions];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
  
  // We should start all our recognizers
  return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer == _pinchGestureRecognizer) {
    return ABS(self.contentOffset.y) <= kToolBarHeight * 0.5 || self.contentOffset.y == kToolBarHeight;
  }
  return YES;
}

- (void)dealloc
{
  self.delegate = nil;
  _pagedScrollView = nil;
}

@end
