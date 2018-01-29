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
  UITapGestureRecognizer *_oneFingerTapGestureRecognizer;
  UITapGestureRecognizer *_twoFingerTapGestureRecognizer;
  UIPinchGestureRecognizer *_pinchGestureRecognizer;
  
  UIPanGestureRecognizer *_pagedPanGestureRecognizer;
  
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
    
    self.alwaysBounceVertical = YES;
    self.alwaysBounceHorizontal = NO;
    self.delaysContentTouches = NO;
    
    self.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    
    // We want only two fingers
    self.panGestureRecognizer.minimumNumberOfTouches = 2;
    self.panGestureRecognizer.maximumNumberOfTouches = 2;
    
    _oneFingerTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleOneFingerTap:)];
    _oneFingerTapGestureRecognizer.numberOfTapsRequired = 1;
    _oneFingerTapGestureRecognizer.numberOfTouchesRequired = 1;
    _oneFingerTapGestureRecognizer.delegate = self;
    
    _twoFingerTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleTwoFingerTap:)];
    _twoFingerTapGestureRecognizer.numberOfTapsRequired = 1;
    _twoFingerTapGestureRecognizer.numberOfTouchesRequired = 2;
    _twoFingerTapGestureRecognizer.delegate = self;
    
    _pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(_handlePinch:)];
    _pinchGestureRecognizer.delegate = self;
    
    // Scroll should wait for us
    [self.panGestureRecognizer requireGestureRecognizerToFail:_oneFingerTapGestureRecognizer];
    [self.panGestureRecognizer requireGestureRecognizerToFail:_twoFingerTapGestureRecognizer];
    
    [_twoFingerTapGestureRecognizer requireGestureRecognizerToFail:_pinchGestureRecognizer];
    
    _controlPanel = [[ControlPanel alloc] initWithFrame:self.bounds];
    [self addSubview:_controlPanel];
    self.delegate = self;
  }
  
  return self;
}

- (void)attachPageViewController:(UIPageViewController *)ctrl
{
  for (UIGestureRecognizer * r in ctrl.view.subviews.firstObject.gestureRecognizers) {
    if ([r isKindOfClass:[UIPanGestureRecognizer class]]) {
      _pagedPanGestureRecognizer = (UIPanGestureRecognizer *)r;
      break;
    }
  }
  
  [_oneFingerTapGestureRecognizer requireGestureRecognizerToFail:_pagedPanGestureRecognizer];
  [_twoFingerTapGestureRecognizer requireGestureRecognizerToFail:_pagedPanGestureRecognizer];
}

// We pass hit test to super view.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
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
  }
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
  CGFloat scale = recognizer.scale;
  
  if (recognizer.state != UIGestureRecognizerStateChanged) {
    self.scrollEnabled = YES;
    self.delaysContentTouches = NO;
    _twoFingerTapGestureRecognizer.enabled = YES;
    return;
  }
  
  if (scale < 0.6 || scale > 1.3) {
    self.scrollEnabled = NO;
    self.delaysContentTouches = NO;
    _twoFingerTapGestureRecognizer.enabled = NO;
    
    [_touchDelegate touchOverlay:self onPinch:recognizer];
  } else {
    _twoFingerTapGestureRecognizer.enabled = YES;
    self.scrollEnabled = YES;
    self.delaysContentTouches = NO;
  }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  [_touchDelegate touchOverlay:self onScrollY:self.contentOffset.y];
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

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
  // We should start all our recognizers
  return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer == _oneFingerTapGestureRecognizer
      || gestureRecognizer == _twoFingerTapGestureRecognizer) {
    return self.isDecelerating;
  }
  
  return YES;
}

- (void)dealloc
{
  self.delegate = nil;
}

@end
