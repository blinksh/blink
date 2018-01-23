//
//  MusicManager.m
//  Blink
//
//  Created by Yury Korolev on 1/23/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import "MusicManager.h"
#import <MediaPlayer/MediaPlayer.h>

@implementation MusicManager

+ (MPMusicPlayerController *)_player
{
  return [MPMusicPlayerController systemMusicPlayer];
}

+ (void)playNext
{
  [[self _player] skipToNextItem];
}

+ (void)playPrev
{
  [[self _player] skipToPreviousItem];
}

+ (void)playBack
{
  [[self _player] skipToBeginning];
}

+ (void)pause
{
  [[self _player] pause];
}

+ (void)play
{
  [[self _player] play];
}

+ (NSString *)trackInfo
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
