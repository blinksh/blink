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

+ (void)playNext
{
  [[MPMusicPlayerController systemMusicPlayer] skipToNextItem];
}

+ (void)playPrev
{
  [[MPMusicPlayerController systemMusicPlayer] skipToPreviousItem];
}

+ (void)pause
{
  [[MPMusicPlayerController systemMusicPlayer] pause];
}

+ (void)play
{
  [[MPMusicPlayerController systemMusicPlayer] play];
}


+ (NSString *)trackInfo
{
  MPMediaItem *item = [[MPMusicPlayerController systemMusicPlayer] nowPlayingItem];
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

+ (NSString *)currentAlbumTitle
{
  return [[MPMusicPlayerController systemMusicPlayer] nowPlayingItem].albumTitle;
}


@end
