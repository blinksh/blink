
#import <Foundation/Foundation.h>
#import "TermStream.h"
#import "TermView.h"
#import "TermInput.h"
#include <sys/ioctl.h>

@interface TermDevice : NSObject

@property (readonly) TermStream *stream;
@property (readonly) TermView *view;
@property (readonly) TermInput *input;
@property (readonly) struct winsize *sz;
@property (nonatomic) BOOL rawMode;

- (void)attachInput:(TermInput *)termInput;
- (void)attachView:(TermView *)termView;

- (void)focus;
- (void)blur;

- (void)write:(NSString *)input;
@end
