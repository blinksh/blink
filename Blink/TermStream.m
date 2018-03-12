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

- (instancetype) dublicate {
  TermStream *dupe = [[TermStream alloc] init];
  dupe.in = fdopen(dup(fileno(_in)), "r");

  // If there is no underlying descriptor (writing to the WV), then duplicate the fterm.
  dupe.out = fdopen(dup(fileno(_out)), "w");
  dupe.err = fdopen(dup(fileno(_err)), "w");
  setvbuf(dupe.out, NULL, _IONBF, 0);
  setvbuf(dupe.err, NULL, _IONBF, 0);

  return dupe;
}

@end
