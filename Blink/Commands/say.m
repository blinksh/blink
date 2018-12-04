////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2018 Blink Mobile Shell Project
//
// This file is part of Blink.
//
// Blink is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Blink is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Blink. If not, see <http://www.gnu.org/licenses/>.
//
// In addition, Blink is also subject to certain additional terms under
// GNU GPL version 3 section 7.
//
// You should have received a copy of these additional terms immediately
// following the terms and conditions of the GNU General Public License
// which accompanied the Blink Source Code. If not, see
// <http://www.github.com/blinksh/blink>.
//
////////////////////////////////////////////////////////////////////////////////

#include <stdio.h>
#include "ios_system/ios_system.h"
#include "ios_error.h"
#include <getopt.h>
#import <AVFoundation/AVFoundation.h>
#import "MCPSession.h"

@interface SpeechSynthesizerDelegate : NSObject<AVSpeechSynthesizerDelegate>

- (void)wait;

@end

@implementation SpeechSynthesizerDelegate {
  dispatch_semaphore_t _sema;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _sema = dispatch_semaphore_create(0);
  }
  return self;
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didCancelSpeechUtterance:(AVSpeechUtterance *)utterance {
  dispatch_semaphore_signal(_sema);
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance {
  dispatch_semaphore_signal(_sema);
}

- (void)wait {
  dispatch_semaphore_wait(_sema, DISPATCH_TIME_FOREVER);
}

@end

void _sayText(NSString *text, NSNumber* rate, AVSpeechSynthesisVoice *voice) {
  AVSpeechUtterance *utterance = [[AVSpeechUtterance alloc] initWithString: text];
  if (rate) {
    utterance.rate = rate.floatValue;
  }
  utterance.pitchMultiplier = 1;
  if (voice) {
    utterance.voice = voice;
  }
  
  SpeechSynthesizerDelegate *delegate = [[SpeechSynthesizerDelegate alloc] init];
  AVSpeechSynthesizer *synth = [[AVSpeechSynthesizer alloc] init];
  synth.delegate = delegate;
  [synth speakUtterance:utterance];
  [delegate wait];
}


int say_main(int argc, char *argv[]) {
  optind = 1;
  
  
  NSString *usage = @"Usage: say [-v voice] [-r rate] [-f file] [message]";
  
  NSString *voice = nil;
  NSString *file = nil;
  NSNumber *rate = nil;
  NSString *text = nil;
    
  for (;;) {
    int c = getopt(argc, argv, "v:f:r:");
    if (c == -1) {
      break;
    }
    
    switch (c) {
      case 'v':
        voice = @(optarg);
        break;
      case 'f':
        file = @(optarg);
        break;
      case 'r':
        rate = @([@(optarg) floatValue]);
        break;
      default:
        printf("%s\n", usage.UTF8String);
        return -1;//[self _exitWithCode:SSH_ERROR andMessage:[self _usage]];
    }
  }
  
  
  if (optind < argc) {
    NSMutableArray<NSString *> *words = [[NSMutableArray alloc] init];
    for (int i = optind; i < argc; i++) {
      [words addObject:@(argv[i])];
    }
    text = [words componentsJoinedByString:@" "];
  }
  
  AVSpeechSynthesisVoice *speechVoice = nil;
  
  if ([voice isEqual:@"?"]) {
    for (AVSpeechSynthesisVoice * v in AVSpeechSynthesisVoice.speechVoices) {
      puts([NSString stringWithFormat:@"%-20s %@\n", v.name.UTF8String, v.language].UTF8String);
    }
    return 0;
  } else if (voice) {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name BEGINSWITH[c] %@", voice];
    speechVoice = [[AVSpeechSynthesisVoice.speechVoices filteredArrayUsingPredicate:predicate] firstObject];
  }
  

  if (!text && file.length > 0) {
    NSError *error = nil;
    text = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:&error];
    if (!text) {
      printf("%s\n", error.localizedDescription.UTF8String);
      return 1;
    }
  }
  
  if (text) {
    _sayText(text, rate, speechVoice);
    return 0;
  }
  
  BOOL isatty = ios_isatty(fileno(thread_stdin));
  
  if (!isatty) {
    if (!text) {
      const int bufsize = 1024;
      char buffer[bufsize];
      NSMutableData* data = [[NSMutableData alloc] init];
      ssize_t count = 0;
      while ((count = read(fileno(thread_stdin), buffer, bufsize-1))) {
        [data appendBytes:buffer length:count];
      }
      
      text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    
    if (!text) {
      printf("%s\n", usage.UTF8String);
      return 1;
    }
    
    _sayText(text, rate, speechVoice);
    return 0;
  }
  
  MCPSession *session = (__bridge MCPSession *)thread_context;
  
  BOOL echoMode = session.device.echoMode;
  [session.device setEchoMode:YES];
  
  for (;;) {
    char * line = NULL;
    size_t len = 0;
    
    ssize_t read = getline(&line, &len, session.device.stream.in);
    if (read <= 0) {
      break;
    }
    puts("");
    _sayText(@(line), rate, speechVoice);
  }
  
  [session.device setEchoMode:echoMode];
  
  return 0;
}

