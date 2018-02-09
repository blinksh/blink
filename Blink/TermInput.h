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

@class UndoManager;

@protocol UndoManagerDelegate
- (void)undoWithManager:(UndoManager *)manager;
- (void)redoWithManager:(UndoManager *)manager;
@end

@interface UndoManager: NSUndoManager
@property (weak) id<UndoManagerDelegate> undoManagerDelegate;
@end

@interface TermInput : UITextView

@property BOOL raw;
@property (weak) id<TerminalDelegate> termDelegate;

- (void)copyLink:(id)sender;
- (void)openLink:(id)sender;
- (void)yank:(id)sender;
- (void)pasteSelection:(id)sender;

@end
