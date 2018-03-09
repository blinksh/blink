//
//  TermStream.h
//  Blink
//
//  Created by Yury Korolev on 3/9/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TermStream : NSObject

@property FILE *in;
@property FILE *out;
@property FILE *err;

- (void)close;

@end
