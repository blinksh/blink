
#import "TermDevice.h"

static int __sizeOfIncompleteSequenceAtTheEnd(const char *buffer, size_t len) {
  // Find the first UTF mark and compare with the iterator.
  int i = 1;
  size_t count = ((len >= 3) ? 3 : len);
  for (; i <= count; i++) {
    unsigned char c = buffer[len - i];
    
    if (i == 1 && (c & 0x80) == 0) {
      // Single simple character, all good
      return 0;
    }
    
    // 10XXX XXXX
    if (c >> 6 == 0x02) {
      continue;
    }
    
    // Check if the character corresponds to the sequence by ORing with it
    if ((i == 2 && ((c | 0xDF) == 0xDF)) || // 110X XXXX 1 1101 1111
        (i == 3 && ((c | 0xEF) == 0xEF)) || // 1110 XXXX 2 1110 1111
        (i == 4 && ((c | 0xF7) == 0xF7))) { // 1111 0XXX 3 1111 0111
      // Complete sequence
      return 0;
    } else {
      return i;
    }
  }
  return 0;
}

@interface TermDevice () <TermViewDeviceProtocol>
@end


// The TermStream is the PTYDevice
// They might actually be different. The Device listens, the stream is lower level.
// The PTY never listens. The Device or Wigdget is a way to indicate that
@implementation TermDevice {
  // Initialized from stream, and make the stream duplicate itself.
  // The stream then has access to the "device" or "widget"
  // The Widget then has functions to read from the stream and pass it.
  int _pinput[2];
  int _poutput[2];
  int _perror[2];
  dispatch_io_t _channel;
  dispatch_queue_t _queue;
  dispatch_data_t _splitChar;
}

- (id)init
{
  self = [super init];
  
  if (self) {
    
    pipe(_pinput);
    pipe(_poutput);
    pipe(_perror);
    
    // TODO: Change the interface
    // Initialize on the stream
    _stream = [[TermStream alloc] init];
    _stream.in = fdopen(_pinput[0], "r");
    _stream.out = fdopen(_poutput[1], "w");
    _stream.err = fdopen(_perror[1], "w");
    setvbuf(_stream.out, NULL, _IONBF, 0);
    setvbuf(_stream.err, NULL, _IONBF, 0);
    setvbuf(_stream.in, NULL, _IONBF, 0);
    
    // Create channel with a callback
    
    _queue = dispatch_queue_create("blink.TermDevice", NULL);
    
    _channel = dispatch_io_create(DISPATCH_IO_STREAM, _poutput[0], _queue,
                                  ^(int error) {
                                    printf("Error creating channel");
                                  });
    
    dispatch_io_set_low_water(_channel, 1);
    //dispatch_io_set_high_water(_channel, SIZE_MAX);
    // TODO: Get read of the main queue on TermView write. It will always happen here.
    dispatch_io_read(_channel, 0, SIZE_MAX, _queue,
                     ^(bool done, dispatch_data_t data, int error) {
                       [self _processStream:data];
                     });
  }
  
  return self;
}

- (void)_processStream:(dispatch_data_t)data
{
  if (_splitChar) {
    data = dispatch_data_create_concat(_splitChar, data);
    _splitChar = nil;
  }
  
  NSData * nsData = (NSData *)data;
  
  NSString *output =  [[NSString alloc] initWithData:nsData encoding:NSUTF8StringEncoding];
  
  // Best case. We got good utf8 seq.
  if (output) {
    [_view write:output];
    return;
  }
  
  // May be we have incomplete utf8 seq at the end;
  const char *buffer = [nsData bytes];
  size_t len = nsData.length;
  int incompleteSize = __sizeOfIncompleteSequenceAtTheEnd(buffer, len);
  
  if (incompleteSize == 0) {
    // No, we didn't find any incomplete seq at the end.
    // We have wrong seq in the middle. Pass base64 data. JS will heal it.
    [_view writeB64:nsData];
    return;
  }

  // Save splitted sequences
  _splitChar = dispatch_data_create_subrange(data, len - incompleteSize, incompleteSize);
  
  // We stripped incomplete seq.
  // Let's try to create string again with range
  
  output = [[NSString alloc] initWithBytes:buffer length:len - incompleteSize encoding:NSUTF8StringEncoding];
  if (output) {
    // Good seq. Write it as string.
    [_view write:output];
    return;
  }
  
  // Nope, fallback to base64
  [_view writeB64:[nsData subdataWithRange:NSMakeRange(0, len - incompleteSize)]];
}

- (void)write:(NSString *)input
{
  write(_pinput[1], [input UTF8String], [input lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
}

- (void)close
{
  // TODO: Closing the streams!! But they are duplicated!!!!
  [_stream close];
  dispatch_io_close(_channel, DISPATCH_IO_STOP);
}

- (void)attachView:(TermView *)termView
{
  _view = termView;
  _view.device = self;
}

- (void)setRawMode:(BOOL)rawMode
{
  _rawMode = rawMode;
  _input.raw = rawMode;
}

- (void)setSecureTextEntry:(BOOL)secureTextEntry
{
  _secureTextEntry = secureTextEntry;
  dispatch_async(dispatch_get_main_queue(), ^{
    if (secureTextEntry == _input.secureTextEntry) {
      return;
    }
    _input.secureTextEntry = secureTextEntry;
    [_input reset];
    [_input reloadInputViews];
  });
}

- (void)dealloc
{
  [self close];
  _input = nil;
  _view = nil;
}

- (void)attachInput:(TermInput *)termInput
{
  _input = termInput;
  if (!_input) {
    [_view blur];
  }
  
  if (_input.device != self) {
    [_input.device attachInput:nil];
    [_input reset];
  }
  
  _input.raw = _rawMode;
  _input.device = self;
  if (_secureTextEntry != _input.secureTextEntry) {
    _input.secureTextEntry = _secureTextEntry;
    [_input reset];
    [_input reloadInputViews];
  }
  
  if ([_input isFirstResponder]) {
    [_view focus];
  } else {
    [_view blur];
  }
}

- (void)focus {
  [_view focus];
  if (![_view.window isKeyWindow]) {
    [_view.window makeKeyWindow];
  }
  if (![_input isFirstResponder]) {
    [_input becomeFirstResponder];
  }
}

- (void)blur {
  [_view blur];
}


#pragma mark - TermViewDeviceProtocol

- (void)viewIsReady
{
  [_delegate deviceIsReady];
}

- (void)viewFontSizeChanged:(NSInteger)size
{
  [_delegate viewFontSizeChanged:size];
}

- (void)viewWinSizeChanged:(struct winsize)newWinSize
{
  if (win.ws_col != newWinSize.ws_col && win.ws_row != newWinSize.ws_row) {
    win.ws_col = newWinSize.ws_col;
    win.ws_row = newWinSize.ws_row;

    [_delegate deviceSizeChanged];
  }
}

- (void)viewSendString:(NSString *)data
{
  [self write:data];
}

- (void)viewCopyString:(NSString *)text
{
  [[UIPasteboard generalPasteboard] setString:text];
}


@end
