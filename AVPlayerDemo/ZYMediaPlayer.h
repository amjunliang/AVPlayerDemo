//
//  ZYMediaPlayer.h
//  AVPlayerDemo
//
//  Created by MaJunliang on 2019/9/11.
//  Copyright © 2019 yiban. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ZYMediaPlayer;
@protocol ZYMediaPlayerDelegate <NSObject>
@optional

- (void)playerDidReadyToPlay:(ZYMediaPlayer *)player;
- (void)playerDidPlayFinish:(ZYMediaPlayer *)player;
- (void)player:(ZYMediaPlayer *)player playToTime:(NSTimeInterval)time;
- (void)player:(ZYMediaPlayer *)player didFailToPlay:(NSError *)error;
- (void)player:(ZYMediaPlayer *)player loadedRangesChanged:(NSArray *)loadedRanges;
- (void)playerDidStalled:(ZYMediaPlayer *)player;
- (void)playbackLikelyToKeepUp:(ZYMediaPlayer *)player;

@end


@interface ZYMediaPlayer : NSObject

@property (nonatomic, strong, readonly)NSString *videoUrl;
@property (nonatomic, weak)id<ZYMediaPlayerDelegate> delegate;
@property (nonatomic, strong, readonly)AVPlayerLayer *layer;

- (instancetype)initWithUrl:(NSString *)videoUrl;

- (void)play;
- (void)pause;
- (void)replay;
- (BOOL)isPlaying;
- (void)seekToTime:(NSTimeInterval)seconds;
- (NSTimeInterval)duration;//视频总时长，单位秒
- (void)mute:(BOOL)mute;//是否静音
- (BOOL)isPlayFinish;

@end

NS_ASSUME_NONNULL_END
