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

- (void)player:(ZYMediaPlayer *)player didReadyToPlay:(NSTimeInterval)duration;
- (void)player:(ZYMediaPlayer *)player didFailToPlay:(NSError *)error;
- (void)playerDidPlayFinish:(ZYMediaPlayer *)player;
- (void)playerDidStalled:(ZYMediaPlayer *)player;
- (void)playerUpdate:(ZYMediaPlayer *)player
         currentTime:(NSTimeInterval)currentTime
   availableDuration:(NSTimeInterval)availableDuration
      resourceLoaded:(BOOL)isLoad;
@end


@interface ZYMediaPlayer : NSObject

@property (nonatomic, strong, readonly)NSString *mediaUrl;
@property (nonatomic, weak)id<ZYMediaPlayerDelegate> delegate;
@property (nonatomic, strong, readonly)AVPlayerLayer *layer;

- (instancetype)initWithUrl:(NSString *)mediaUrl;
- (void)play;
- (void)pause;
- (void)replay;
- (void)seekToTime:(NSTimeInterval)seconds
          complete:(void (^)(BOOL finished))complete;
- (NSTimeInterval)duration;//视频总时长，单位秒
- (void)mute:(BOOL)mute;//是否静音

- (BOOL)isPlayFinish;
- (BOOL)isPlaying;

- (void)presentFullScreen:(UIViewController *)fromVC;
@end

NS_ASSUME_NONNULL_END
