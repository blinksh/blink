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


extern NSString * const TermViewCtrlSeq;
extern NSString * const TermViewEscSeq;
extern NSString * const TermViewCursorFuncSeq;
extern NSString * const TermViewFFuncSeq;
extern NSString * const TermViewAutoRepeateSeq;


@interface TermInput : UITextView
@property BOOL raw;

@property (weak) id<TerminalDelegate> termDelegate;

- (void)assignSequence:(NSString *)seq toModifier:(UIKeyModifierFlags)modifier;
- (void)assignKey:(NSString *)key toModifier:(UIKeyModifierFlags)modifier;
- (void)assignFunction:(NSString *)function toTriggers:(UIKeyModifierFlags)triggers;
- (void)resetDefaultControlKeys;
@end
