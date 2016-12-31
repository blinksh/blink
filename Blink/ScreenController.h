//
//  ScreenController.h
//  Blink
//
//  Created by Yury Korolev on 31/12/2016.
//  Copyright © 2016 Carlos Cabañero Projects SL. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ScreenController : NSObject

+ (ScreenController *)shared;

- (void)setup;
- (void)switchToOtherScreen;
- (void)moveCurrentShellToOtherScreen;


@end
