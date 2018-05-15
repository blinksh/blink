//
//  Repl.h
//  Blink
//
//  Created by Yury Korolev on 5/14/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TermDevice.h"

@interface Repl : NSObject

- (instancetype)initWithDevice:(TermDevice *)device;

- (void)kill;
- (void)sigwinch;
- (void)loopWithCallback:(BOOL(^)(NSString *cmd)) callback;

- (int)clear_main:(int)argc argv:(char **)argv;
- (int)history_main:(int)argc argv:(char **)argv;
@end
