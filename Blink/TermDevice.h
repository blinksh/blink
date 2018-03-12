
#import <Foundation/Foundation.h>
#import "TermStream.h"
#import "TermView.h"
#import "TermInput.h"
#include <sys/ioctl.h>

@protocol TermDeviceDelegate

- (void)deviceIsReady;
- (void)deviceSizeChanged;
- (void)viewFontSizeChanged:(NSInteger)size;

@end


@interface TermDevice : NSObject
{
  @public struct winsize win;
}

@property (readonly) TermStream *stream;
@property (readonly) TermView *view;
@property (readonly) TermInput *input;
@property (weak) id<TermDeviceDelegate> delegate;
@property (nonatomic) BOOL rawMode;
@property (nonatomic) BOOL secureTextEntry;

- (void)attachInput:(TermInput *)termInput;
- (void)attachView:(TermView *)termView;

- (void)focus;
- (void)blur;

- (void)write:(NSString *)input;

@end
