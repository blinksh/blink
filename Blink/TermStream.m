//
//  TermStream.m
//  Blink
//
//  Created by Yury Korolev on 3/9/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import "TermStream.h"

@implementation TermStream

- (void)close
{
  if (_in) {
    fclose(_in);
    _in = NULL;
  }
  if (_out) {
    fclose(_out);
    _out = NULL;
  }
  if (_err) {
    fclose(_err);
    _err = NULL;
  }
}

@end
