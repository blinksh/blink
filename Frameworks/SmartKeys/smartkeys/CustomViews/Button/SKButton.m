//
//  SKButton.m
//  smartkeys
//
//  Created by Atul M on 27/10/16.
//  Copyright © 2016 CARLOS CABANERO. All rights reserved.
//

#import "SKButton.h"

@implementation SKButton
@synthesize backgroundLayer;

- (void)animatedButtonSelection:(BOOL)selected{
    if(selected){
        if(self.backgroundLayer != nil){
            [self.backgroundLayer removeFromSuperlayer];
        }
        self.backgroundLayer = [[CALayer alloc]init];
        self.backgroundLayer.cornerRadius = 5;
        self.backgroundLayer.frame = CGRectMake(2, 2, self.frame.size.width-4, self.frame.size.height-4);
        self.backgroundLayer.backgroundColor = [UIColor colorWithRed:86.0/255.0 green:234.0/255.0 blue:241.0/255.0 alpha:1.0].CGColor;
        
        CABasicAnimation *theAnimation=[CABasicAnimation animationWithKeyPath:@"opacity"];
        theAnimation.duration=0.2;
        theAnimation.fromValue=[NSNumber numberWithFloat:0.0];
        theAnimation.toValue=[NSNumber numberWithFloat:1.0];
        [self.backgroundLayer addAnimation:theAnimation forKey:@"animateOpacity"];
        
        [self.layer insertSublayer:self.backgroundLayer atIndex:0];
    }else{
        self.backgroundLayer.opacity = 0.0;

        [CATransaction begin];
        CABasicAnimation *theAnimation=[CABasicAnimation animationWithKeyPath:@"opacity"];
        theAnimation.duration=0.2;
        theAnimation.fromValue=[NSNumber numberWithFloat:1.0];
        theAnimation.toValue=[NSNumber numberWithFloat:0.0];
        [CATransaction setCompletionBlock:^{
            if(self.backgroundLayer != nil){
                [self.backgroundLayer removeFromSuperlayer];

            }
        }];
        [self.backgroundLayer addAnimation:theAnimation forKey:@"animateOpacity"];
        [CATransaction commit];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.backgroundLayer.frame = CGRectMake(2, 2, self.frame.size.width-4, self.frame.size.height-4);
}
@end
