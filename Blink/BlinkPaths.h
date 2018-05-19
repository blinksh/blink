//
//  BlinkPaths.h
//  Blink
//
//  Created by Yury Korolev on 5/14/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BlinkPaths : NSObject


+ (NSString *) documents;
+ (NSURL *) documentsURL;
+ (NSString *) blink;
+ (NSURL *) blinkURL;
+ (NSString *) historyFile;
+ (NSString *) knownHostsFile;
+ (NSString *) defaultsFile;


@end
