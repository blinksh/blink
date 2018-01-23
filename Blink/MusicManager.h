//
//  MusicManager.h
//  Blink
//
//  Created by Yury Korolev on 1/23/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MusicManager : NSObject

+ (void)playPrev;
+ (void)playNext;
+ (void)pause;
+ (void)play;
+ (void)playBack;
+ (NSString *)trackInfo;

@end
