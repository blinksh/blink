//
//  InputView.h
//  Blink
//
//  Created by Yury Korolev on 1/12/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "TermView.h"

@interface TermInput : UITextView

@property BOOL raw;
@property (weak) id<TerminalDelegate> termDelegate;

@end
