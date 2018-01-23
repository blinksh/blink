//
//  MusicManager.h
//  Blink
//
//  Created by Yury Korolev on 1/23/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MusicManager : NSObject

+ (MusicManager *)shared;

- (void)onShow;
- (void)onHide;

- (UIView *)hudView;

- (NSArray<UIKeyCommand *> *)keyCommands;
- (void)handleCommand:(UIKeyCommand *)cmd;

- (NSArray<NSString *> *)commands;
- (NSString *)runWithInput:(NSString *)input;

@end
