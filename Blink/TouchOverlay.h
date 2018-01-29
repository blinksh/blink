//
//  TouchOverlay.h
//  Blink
//
//  Created by Yury Korolev on 1/29/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import <UIKit/UIKit.h>

@class TouchOverlay;

@protocol TouchOverlayDelegate

- (void)touchOverlay:(TouchOverlay *)overlay onOneFingerTap:(UITapGestureRecognizer *)recognizer;
- (void)touchOverlay:(TouchOverlay *)overlay onTwoFingerTap:(UITapGestureRecognizer *)recognizer;
- (void)touchOverlay:(TouchOverlay *)overlay onPinch:(UIPinchGestureRecognizer *)recognizer;
- (void)touchOverlay:(TouchOverlay *)overlay onScrollY:(CGFloat) y;

@end

@interface TouchOverlay : UIScrollView

@property (weak) id<TouchOverlayDelegate> touchDelegate;

- (void)attachPageViewController:(UIPageViewController *)ctrl;

@end
