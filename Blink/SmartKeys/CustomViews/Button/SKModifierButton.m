//
//  SKModifierButton.m
//  smartkeys
//
//  Created by Atul M on 26/10/16.
//  Copyright © 2016 CARLOS CABANERO. All rights reserved.
//

#import "SKModifierButton.h"

#define DEFAULT_BG_COLOR  [UIColor viewFlipsideBackgroundColor];
#define SELECTED_BG_COLOR [UIColor blueColor]

@implementation SKModifierButton

-(void)setSelected:(BOOL)selected{
    [super setSelected:selected];
    [super animatedButtonSelection:selected];
}

@end
