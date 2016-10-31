//
//  SKNonModifierButton.m
//  smartkeys
//
//  Created by Atul M on 27/10/16.
//  Copyright © 2016 CARLOS CABANERO. All rights reserved.
//

#import "SKNonModifierButton.h"
@implementation SKNonModifierButton

- (void)setHighlighted:(BOOL)highlighted{
    [super setHighlighted:highlighted];
    [super animatedButtonSelection:highlighted];
}

@end
