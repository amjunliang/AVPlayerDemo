//
//  ZYMediaPlayer.m
//  AVPlayerDemo
//
//  Created by MaJunliang on 2019/9/11.
//  Copyright © 2019 yiban. All rights reserved.
//

#import "ZYMediaPlayer.h"

@interface ZYMediaPlayer () {
    AVPlayer *_player;
    AVPlayerLayer *_playerLayer;
    AVPlayerItem *_playerItem;
    
    id _playerTimeObserver;
}

@property (nonatomic, strong)NSString *videoUrl;
@property(nonatomic, strong) CADisplayLink *link; //卡顿监控

@end

@implementation ZYMediaPlayer

- (instancetype)initWithUrl:(NSString *)videoUrl
{
    if (videoUrl.length == 0) {
        return nil;
    }
    
    if (self = [super init]) {
        self.videoUrl = videoUrl;
        [self setup];
    }
    return self;
}
- (void)dealloc {
    [_player pause];

    [self removeObserver];
}

- (void)play {
    if ([self isPlaying]) {
        return;
    }
    NSError *error;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:&error];
    if (error) {
        NSLog(@"%@", error);
    }
    [_player play];
}

- (void)replay {
    [_player seekToTime:kCMTimeZero];
    [self play];
}

- (void)pause {
    if (![self isPlaying]) {
        return;
    }
    [_player pause];
}

- (BOOL)isPlaying {
    return _player.rate != 0;
}

- (BOOL)isPlayFinish {
    if ([self duration] == 0) {
        return NO;
    }
    BOOL result = [self duration] > [self currentTime];
    return !result;
}

- (void)seekToTime:(NSTimeInterval)seconds {
    NSTimeInterval time = seconds;
    if (time < 0) {
        time = 0;
    }
    NSTimeInterval duration = [self duration];
    if (time > duration) {
        time = duration;
    }
    [_player seekToTime:CMTimeMake(time, 1)];
}

- (NSTimeInterval)duration {
    NSTimeInterval duration = CMTimeGetSeconds(_player.currentItem.duration);
    return duration;
}

- (NSTimeInterval)currentTime {
    NSTimeInterval time = CMTimeGetSeconds(_player.currentTime);
    return time;
}

- (void)mute:(BOOL)mute {
    _player.muted = mute;
}

- (AVPlayerLayer *)layer {
    return _playerLayer;
}

#pragma mark - Private

- (void)removePlayLoadingCheck
{
    [self.link invalidate];
    self.link = nil;
}
- (void)addPlayLoadingCheck
{
    self.link = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateUI)];
    [self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)setup {
    if (self.videoUrl.length == 0) {
        return;
    }
    NSURL *url = [NSURL URLWithString:self.videoUrl];
    if (!url) {
        return;
    }
    _playerItem = [AVPlayerItem playerItemWithURL:url];
    _player = [AVPlayer playerWithPlayerItem:_playerItem];
    //0.2秒刷新一次
    __weak typeof(self) weakSelf = self;
    _playerTimeObserver = [_player addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 5.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        if ([weakSelf duration] > 0) {
            CGFloat playDuration = CMTimeGetSeconds(time);
            if (weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(player:playToTime:)]) {
                [weakSelf.delegate player:weakSelf playToTime:playDuration];
            }
        }
    }];
    //107216 正式
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
    _playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    
    [self addObserver];
}

- (void)addObserver {
    if (!_player.currentItem) {
        return;
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playFinished:) name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playFailed:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:_player.currentItem];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playStalled:) name:AVPlayerItemPlaybackStalledNotification object:_player.currentItem];
    
    [_player.currentItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:nil];//播放状态
    [_player addObserver:self forKeyPath:@"rate" options:NSKeyValueObservingOptionNew context:nil];//播放速率
    [_player.currentItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];//缓冲
    [_player.currentItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];//是否可播放
    [_player.currentItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)removeObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_player removeTimeObserver:_playerTimeObserver];
    [_player.currentItem removeObserver:self forKeyPath:@"status"];
    [_player removeObserver:self forKeyPath:@"rate"];
    [_player.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [_player.currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    [_player.currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
}

- (void)playStalled:(NSNotification *)notification {
    if (self.delegate && [self.delegate respondsToSelector:@selector(playerDidStalled:)]) {
        [self.delegate playerDidStalled:self];
    }
}

- (void)playFinished:(NSNotification *)notification {
    if (self.delegate && [self.delegate respondsToSelector:@selector(playerDidPlayFinish:)]) {
        [self.delegate playerDidPlayFinish:self];
    }
}

- (void)playFailed:(NSNotification *)notification {
    if (self.delegate && [self.delegate respondsToSelector:@selector(player:didFailToPlay:)]) {
        [self.delegate player:self didFailToPlay:_playerItem.error];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (_player == nil) {
        return;
    }
    if ([keyPath isEqualToString:@"status"]) {//播放状态
        
        switch (_player.currentItem.status) {
            case AVPlayerItemStatusUnknown:
                //资源尚未载入，不在播放队列中
                break;
            case AVPlayerItemStatusReadyToPlay:
                if (self.delegate && [self.delegate respondsToSelector:@selector(playerDidReadyToPlay:)]) {
                    [self.delegate playerDidReadyToPlay:self];
                }
                break;
            case AVPlayerItemStatusFailed:
                if (self.delegate && [self.delegate respondsToSelector:@selector(player:didFailToPlay:)]) {
                    [self.delegate player:self didFailToPlay:_player.currentItem.error];
                }
                break;
            default:
                break;
        }
    } else if ([keyPath isEqualToString:@"rate"]) {//播放速率
        
    } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {//缓冲
        if (self.delegate && [self.delegate respondsToSelector:@selector(player:loadedRangesChanged:)]) {
            [self.delegate player:self loadedRangesChanged:_player.currentItem.loadedTimeRanges];
        }
    } else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {//buffer好了，可播放
        if (_player.currentItem.playbackLikelyToKeepUp) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(playbackLikelyToKeepUp:)]) {
                [self.delegate playbackLikelyToKeepUp:self];
            }
        }
    } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) { //buffer空了
        if (_player.currentItem.playbackBufferEmpty) {
            
        }
    }
}

@end
