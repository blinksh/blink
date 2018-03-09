
#import "TermDevice.h"



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
  struct winsize *_termsz;
  dispatch_io_t _channel;
  dispatch_queue_t _queue;
  dispatch_data_t _splitChar;
  TermController *_control;
}

// Creates descriptors
// NO. This should be part of the control. Opens / runs a session on a pty device
//   When creating the session, we pass it the descriptors
// Manages master / slave transparently between the descriptors.
// Replaces fterm
// Signals here too instead of in TermController? Signals might depend on the Session though. How is this done in real UNIX? How is the signal sent to the process if the pty knows nothing?

// TODO: Temporary fix, get rid of the control in the Stream?
// This smells like the Device will have to implement this functions, wrapping the Widget. Wait and see...
- (void)setControl:(TermController *)control
{
  _control = control;
  _stream.control = control;
}

- (TermController *)control
{
  return _control;
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
    
    // TODO: Can we take the size outside the stream too?
    // Although in some way the size should belong to the pty.
    _termsz = malloc(sizeof(struct winsize));
    _stream.sz = _termsz;
    
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
                       [self _parseStream:data];
                     });
    
  }
  
  return self;
}

- (void)_parseStream:(dispatch_data_t)data
{
  if (_splitChar) {
    data = dispatch_data_create_concat(_splitChar, data);
    _splitChar = nil;
  }
  
  NSData * nsData = (NSData *)data;
  
  NSString *output =  [[NSString alloc] initWithData:nsData encoding:NSUTF8StringEncoding];
  
  // Best case. We got good utf8 seq.
  if (output) {
    [_control.termView write:output];
    return;
  }
  
  // May be we have incomplete utf8 seq at the end;
  
  size_t len = dispatch_data_get_size(data);
  const char *buffer = [nsData bytes];

  // Find the first UTF mark and compare with the iterator.
  int i = 1;
  for (; i <= ((len >= 3) ? 3 : len); i++) {
    unsigned char c = buffer[len - i];
    
    if (i == 1 && (c & 0x80) == 0) {
      // Single simple character, all good
      i=0;
      break;
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
      i=0;
      break;
    } else {
      // Save splitted sequences
      _splitChar = dispatch_data_create_subrange(data, len - i, i);
      break;
    }
  }
  
  // No, we didn't find any incomplete seq at the end.
  // pass base64 data. JS will heal it.
  if (!_splitChar) {
    [_control.termView writeB64:nsData];
    return;
  }
  
  // We stripped incomplete seq.
  // Let's try to create string again with range
  nsData = [nsData subdataWithRange:NSMakeRange(0, len - i)];
  output = [[NSString alloc] initWithData:nsData encoding:NSUTF8StringEncoding];
  if (output) {
    // Good seq. Write it as string.
    [_control.termView write:output];
  } else {
    // Nope, fallback to base64
    [_control.termView writeB64:nsData];
  }
}

- (void)write:(NSString *)input
{
  const char *str = [input UTF8String];
  write(_pinput[1], str, [input lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
}

- (void)close
{
  // TODO: Close the channel
  // TODO: Closing the streams!! But they are duplicated!!!!
  [_stream close];
//  if (_pinput) {
//    fclose(_pinput);
//  }
//  if (_poutput) {
//    fclose(_poutput);
//  }
//  if (_perror) {
//    fclose(_perror);
//  }
  if (_termsz) {
    free(_termsz);
    _termsz = NULL;
  }
}

- (void)dealloc
{
  [self close];
}

@end
