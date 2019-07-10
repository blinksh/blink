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

#import "MusicManager.h"
#import <MediaPlayer/MediaPlayer.h>
#import "BKUserConfigurationManager.h"
#import "RoundedToolbar.h"

@implementation MusicManager {
  UIToolbar *_toolbar;
  UIToolbar *_controlPanelToolbar;
  NSArray<UIKeyCommand *> *_keyCommands;
}

+ (MusicManager *)shared {
  static MusicManager *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[self alloc] init];
  });
  return instance;
}

- (instancetype)init
{
  if (self = [super init]) {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    [center addObserver:self
               selector:@selector(_playbackStateDidChange)
                   name:MPMusicPlayerControllerPlaybackStateDidChangeNotification object:nil];

    [[self _player] beginGeneratingPlaybackNotifications];
  }
  
  return self;
}

- (UIView *)hudView
{
  if (!_toolbar) {
    _toolbar = [[RoundedToolbar alloc] initWithFrame:CGRectZero];
  }
  
  _toolbar.items = [self _toolbarItems];
  
  return _toolbar;
}

- (UIView *)controlPanelView
{
  if (!_controlPanelToolbar) {
    _controlPanelToolbar = [[RoundedToolbar alloc] initWithFrame:CGRectZero];
  }
  
  _controlPanelToolbar.items = [self _toolbarItems];
  
  return _controlPanelToolbar;
}


- (NSArray<UIBarButtonItem *> *)_toolbarItems
{
  UIBarButtonItem *prev = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemRewind target:self action:@selector(_playPrev)];
  UIBarButtonItem *space1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
  space1.width = 24;
  UIBarButtonItem *space2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
  space2.width = 24;
  UIBarButtonItem *play = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(_play)];
  UIBarButtonItem *pause = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause target:self action:@selector(_pause)];
  
  UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFastForward target:self action:@selector(_playNext)];
  
  BOOL isPlaying = [self _player].playbackState == MPMusicPlaybackStatePlaying;
  
  return @[prev, space1, isPlaying ? pause : play, space2, next];
}

- (void)_playbackStateDidChange
{
  _toolbar.items = [self _toolbarItems];
  _controlPanelToolbar.items = [self _toolbarItems];
}

- (NSArray<UIKeyCommand *> *)keyCommands
{
  if (!_keyCommands) {
    UIKeyModifierFlags modifierFlags = [BKUserConfigurationManager shortCutModifierFlags];

    UIKeyCommand *next = [UIKeyCommand keyCommandWithInput:@"n"
                                             modifierFlags:modifierFlags
                                                    action:@selector(musicCommand:)];
    next.discoverabilityTitle = NSLocalizedString(@"Next track", nil);

    UIKeyCommand *pause = [UIKeyCommand keyCommandWithInput:@"s"
                                              modifierFlags:modifierFlags
                                                     action:@selector(musicCommand:)];
    pause.discoverabilityTitle = NSLocalizedString(@"Pause", nil);

    UIKeyCommand *play = [UIKeyCommand keyCommandWithInput:@"p"
                                             modifierFlags:modifierFlags
                                                    action:@selector(musicCommand:)];
    play.discoverabilityTitle = NSLocalizedString(@"Play", nil);

    UIKeyCommand *previous = [UIKeyCommand keyCommandWithInput:@"r"
                                                 modifierFlags:modifierFlags
                                                        action:@selector(musicCommand:)];
    previous.discoverabilityTitle = NSLocalizedString(@"Previous track", nil);

    UIKeyCommand *beginning = [UIKeyCommand keyCommandWithInput:@"b"
                                                  modifierFlags:modifierFlags
                                                         action:@selector(musicCommand:)];
    beginning.discoverabilityTitle = NSLocalizedString(@"Play from beginning", nil);

    UIKeyCommand *toggle = [UIKeyCommand keyCommandWithInput:@"m"
                                               modifierFlags:modifierFlags
                                                      action:@selector(_toggleMusicHUD)];

    _keyCommands = @[ next, pause, play, previous, beginning, toggle ];
  }
  
  return _keyCommands;
}

- (void)_toggleMusicHUD
{
  // See this method in SpaceController
}

- (void)musicCommand:(UIKeyCommand *)cmd
{
}

- (void)handleCommand:(UIKeyCommand *)cmd
{
  [self runWithInput:cmd.input];
}

- (NSArray<NSString *> *)commands
{
  return @[@"info", @"back", @"prev", @"pause", @"play", @"resume", @"next"];
}

-(NSString *)runWithInput:(NSString *)input
{
  if ([input isEqualToString:@""] || [input isEqualToString:@"info"]) {
    NSString *info = [self _trackInfo];
    if (info) {
      return [NSString stringWithFormat:@"Current track: %@", info];
    }
  } else if ([input isEqualToString:@"next"] || [input isEqualToString:@"n"]) {
    [self _playNext];
  } else if ([input isEqualToString:@"prev"] || [input isEqualToString:@"r"]) {
    [self _playPrev];
  } else if ([input isEqualToString:@"pause"] || [input isEqualToString:@"s"]) {
    [self _pause];
  } else if ([input isEqualToString:@"play"] || [input isEqualToString:@"p"] || [input isEqualToString:@"resume"]) {
    [self _play];
  } else if ([input isEqualToString:@"back"] || [input isEqualToString:@"b"]) {
    [self _playBack];
  } else {
    return @"Unknown parameter";
  }
  
  return nil;
}

- (MPMusicPlayerController *)_player
{
  return [MPMusicPlayerController systemMusicPlayer];
}

- (void)_playNext
{
  [[self _player] skipToNextItem];
}

- (void)_playPrev
{
  [[self _player] skipToPreviousItem];
}

- (void)_playBack
{
  [[self _player] skipToBeginning];
}

- (void)_pause
{
  [[self _player] pause];
}

- (void)_play
{
  [[self _player] play];
}

- (NSString *)_trackInfo
{
  MPMediaItem *item = [[self _player] nowPlayingItem];
  if (!item) {
    return @"Unknown";
  }
  NSMutableArray *components = [[NSMutableArray alloc] init];
  if (item.title) {
    [components addObject:item.title];
  }
  if (item.artist) {
    [components addObject:item.artist];
  }
  if (item.albumTitle) {
    [components addObject:item.albumTitle];
  }
  
  return [components componentsJoinedByString:@". "];
}

@end
