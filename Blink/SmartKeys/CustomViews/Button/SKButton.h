//
//  SKButton.h
//  smartkeys
//
//  Created by Atul M on 27/10/16.
//  Copyright © 2016 CARLOS CABANERO. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SKButton : UIButton

@property (nonatomic, strong) CALayer *backgroundLayer;

- (void)animatedButtonSelection:(BOOL)selected;

@end
